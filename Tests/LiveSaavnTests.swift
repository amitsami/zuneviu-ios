import XCTest
import AVFoundation
@testable import Zuneviu

// Real provider acceptance, deliberately excluded from offline/fixture suites.
// A failure remains a failure. No fixture URL or substitute provider is allowed.
final class LiveSaavnTests: XCTestCase {
    @MainActor func testRealSearchPlaybackSeekDownloadAndOfflinePlayback() async throws {
        let songs = try await SaavnService.shared.search("Tum Hi Ho")
        let track = try XCTUnwrap(songs.first { $0.title == "Tum Hi Ho" && $0.artist.localizedCaseInsensitiveContains("Arijit") && $0.duration > 200 })
        XCTAssertNotNil(track.saavnID); XCTAssertNil(track.videoID)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let prefs = PreferenceStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        prefs.values.saavnEnabled = true; prefs.values.wifiOnlyDownloads = false
        let library = LibraryStore(root: root)
        let discovery = DiscoveryStore(root: root, preferences: prefs)
        let engine = PlaybackStore(library: library, preferences: prefs, discovery: discovery)
        defer { engine.stop() }
        engine.play(track, in: [track])
        for _ in 0..<160 { if engine.error != nil || engine.position > 1 { break }; try await Task.sleep(nanoseconds: 500_000_000) }
        XCTAssertNil(engine.error); XCTAssertTrue(engine.isPlaying); XCTAssertGreaterThan(engine.position, 1)
        guard engine.isPlaying else { XCTFail("Real source playback did not start"); return }
        engine.pause(); try await Task.sleep(nanoseconds: 300_000_000)
        let stopped = engine.position; try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(engine.position, stopped, accuracy: 0.2)
        engine.seek(15); try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(engine.position, 15, accuracy: 1)
        engine.resume(); try await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertGreaterThan(engine.position, 15.5)
        for _ in 0..<100 { if !discovery.seeds.isEmpty { break }; try await Task.sleep(nanoseconds: 250_000_000) }
        XCTAssertEqual(discovery.seeds.first?.id, track.id, "Only real listening, not seeking, should qualify discovery")
        engine.stop()
        await discovery.refresh()
        XCTAssertFalse(discovery.suggestions.isEmpty, "Real qualified source should return local-taste suggestions")
        XCTAssertFalse(discovery.suggestions.contains { $0.id == track.id })
        let manager = DownloadManager(library: library, preferences: prefs, network: NetworkStatus.shared)
        manager.enqueue(track)
        for _ in 0..<240 {
            if let state = manager.jobs.first?.state, [DownloadState.completed, .failed].contains(state) { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertEqual(manager.jobs.first?.state, .completed, manager.jobs.first?.message ?? "No download result")
        guard manager.jobs.first?.state == .completed else { return }
        let downloaded = try XCTUnwrap(LibraryStore(root: root).track(track.id))
        XCTAssertTrue(downloaded.isLocal); XCTAssertNotNil(downloaded.downloadedAt)
        XCTAssertGreaterThan(downloaded.duration, 240, "Must be full audio, not a preview")
        // Disable the online source, then load only the persisted local file.
        prefs.values.saavnEnabled = false
        engine.play(downloaded, in: [downloaded])
        let asset = try XCTUnwrap(engine.player.currentItem?.asset as? AVURLAsset)
        XCTAssertTrue(asset.url.isFileURL, "Offline playback must not request an online audio URL")
        for _ in 0..<80 { if engine.error != nil || engine.position > 1 { break }; try await Task.sleep(nanoseconds: 250_000_000) }
        XCTAssertNil(engine.error); XCTAssertGreaterThan(engine.position, 1)
    }
}
