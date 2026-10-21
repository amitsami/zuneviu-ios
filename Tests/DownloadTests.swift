import XCTest
@preconcurrency import AVFoundation
@testable import Zuneviu

final class DownloadTests: XCTestCase {
    private func song(duration: Double = 0) -> Track {
        Track(id: UUID(), title: "Download fixture", artist: "Test only", album: "", audioFile: "", duration: duration, importedAt: Date(), videoID: "fixture0001")
    }
    @MainActor private func prefs() -> PreferenceStore { PreferenceStore(defaults: UserDefaults(suiteName: UUID().uuidString)!) }
    @MainActor private func wait(_ manager: DownloadManager, state: DownloadState) async throws {
        for _ in 0..<100 {
            if manager.jobs.first?.state == state { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Expected \(state), got \(String(describing: manager.jobs.first?.state))")
    }
    @MainActor func testFixtureTransferInstallsPersistsAndPlaysOffline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root), preferences = prefs()
        let source = try XCTUnwrap(Bundle.main.url(forResource: "TestTone", withExtension: "wav"))
        let manager = DownloadManager(library: library, preferences: preferences, network: NetworkStatus(initial: .wifi, monitor: false), resolver: { _, _ in URL(string: "https://example.invalid/fixture-only")! }, fetcher: { _, _, progress in
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: source, to: temporary)
            progress(100, 100); return temporary
        })
        let track = song(); manager.enqueue(track); manager.enqueue(track)
        try await wait(manager, state: .completed)
        XCTAssertEqual(manager.jobs.count, 1); XCTAssertEqual(library.downloads.count, 1)
        let saved = try XCTUnwrap(LibraryStore(root: root).track(track.id))
        XCTAssertTrue(saved.isLocal); XCTAssertNotNil(saved.downloadedAt)
        let engine = PlaybackStore(library: library, preferences: preferences)
        defer { engine.stop() }
        engine.play(saved, in: [saved])
        for _ in 0..<50 { if engine.position > 0.5 { break }; try await Task.sleep(nanoseconds: 100_000_000) }
        XCTAssertGreaterThan(engine.position, 0.5, "Downloaded fixture must advance using the on-device file, not network")
        XCTAssertNil(engine.error)
        manager.enqueue(track); XCTAssertEqual(manager.jobs.count, 1)
        let json = try String(contentsOf: library.file("download-queue.json"), encoding: .utf8)
        XCTAssertFalse(json.contains("example.invalid"), "Resolved media URLs must never be persisted")
    }
    @MainActor func testExtensionlessAACDownloadValidatesAndPlaysPersistedCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        let source = try XCTUnwrap(Bundle.main.url(forResource: "TestTone", withExtension: "wav"))
        let encoded = library.file("fixture.m4a")
        let export = try XCTUnwrap(AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetAppleM4A))
        export.outputURL = encoded; export.outputFileType = .m4a
        await withCheckedContinuation { continuation in export.exportAsynchronously { continuation.resume() } }
        XCTAssertEqual(export.status, .completed, export.error?.localizedDescription ?? "AAC fixture export failed")
        let temporary = library.file("extensionless-transfer")
        try FileManager.default.moveItem(at: encoded, to: temporary)
        let track = song()
        try await library.installDownload(track, temporaryFile: temporary)
        let saved = try XCTUnwrap(LibraryStore(root: root).track(track.id))
        XCTAssertTrue(saved.audioFile.hasSuffix(".m4a")); XCTAssertNotNil(saved.downloadedAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.path), "Never consume caller's original file")
        let engine = PlaybackStore(library: library, preferences: prefs())
        defer { engine.stop() }
        engine.play(saved, in: [saved])
        for _ in 0..<60 { if engine.position > 0.5 { break }; try await Task.sleep(nanoseconds: 100_000_000) }
        XCTAssertNil(engine.error); XCTAssertGreaterThan(engine.position, 0.5)
    }
    @MainActor func testWifiOnlyWaitsWithoutCallingResolver() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = DownloadManager(library: LibraryStore(root: root), preferences: prefs(), network: NetworkStatus(initial: .cellular, monitor: false), resolver: { _, _ in XCTFail("Wi-Fi policy must block resolution"); throw MusicServiceError.noStream })
        manager.enqueue(song())
        XCTAssertEqual(manager.jobs.first?.state, .waitingForWifi)
        manager.cancel(manager.jobs[0].id); XCTAssertEqual(manager.jobs.first?.state, .cancelled)
    }
    @MainActor func testResolverFailureDoesNotCreateOfflineEntry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        let manager = DownloadManager(library: library, preferences: prefs(), network: NetworkStatus(initial: .wifi, monitor: false), resolver: { _, _ in throw MusicServiceError.noStream })
        manager.enqueue(song()); try await wait(manager, state: .failed)
        XCTAssertTrue(library.downloads.isEmpty); XCTAssertTrue(library.tracks.isEmpty)
    }
    @MainActor func testCancelDuringResolutionNeverInstallsAudio() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        let manager = DownloadManager(library: library, preferences: prefs(), network: NetworkStatus(initial: .wifi, monitor: false), resolver: { _, _ in try await Task.sleep(nanoseconds: 500_000_000); return URL(string: "https://example.invalid")! })
        let track = song(); manager.enqueue(track)
        try await Task.sleep(nanoseconds: 30_000_000); manager.cancel(track.id)
        try await wait(manager, state: .cancelled)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(library.onDevice.isEmpty); XCTAssertEqual(manager.jobs.first?.state, .cancelled)
    }
    @MainActor func testRestoredActiveJobRequiresRetryAndCorruptQueueIsPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        var job = DownloadJob(track: song()); job.state = .downloading
        try JSONEncoder().encode([job]).write(to: library.file("download-queue.json"))
        let manager = DownloadManager(library: library, preferences: prefs(), network: NetworkStatus(initial: .offline, monitor: false))
        XCTAssertEqual(manager.jobs.first?.state, .interrupted)
        let bad = Data("corrupt queue".utf8); try bad.write(to: library.file("download-queue.json"))
        let broken = DownloadManager(library: library, preferences: prefs(), network: NetworkStatus(initial: .wifi, monitor: false))
        XCTAssertNotNil(broken.persistenceError); broken.enqueue(song())
        XCTAssertEqual(try Data(contentsOf: library.file("download-queue.json")), bad)
    }
    @MainActor func testShortAndInvalidFilesCannotBecomeDownloads() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        let source = try XCTUnwrap(Bundle.main.url(forResource: "TestTone", withExtension: "wav"))
        do { try await library.installDownload(song(duration: 600), temporaryFile: source); XCTFail("Short preview cannot satisfy full song") } catch { }
        let invalid = library.file("invalid.m4a"); try Data("not audio".utf8).write(to: invalid)
        do { try await library.installDownload(song(), temporaryFile: invalid); XCTFail("Invalid audio must be rejected") } catch { }
        XCTAssertTrue(library.onDevice.isEmpty); XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix("download-") }, "Failed validation must remove staged copies")
    }
    func testTransferRejectsInsecureURL() async {
        do { _ = try await DownloadTransfer(progress: { _, _ in }).fetch(URL(string: "http://example.invalid/audio")!, wifiOnly: true); XCTFail("HTTP must be rejected") } catch { }
    }
}
