import XCTest
import AVFoundation
@testable import Zuneviu

final class PlaybackTests: XCTestCase {
    @MainActor func testNativePlaybackAdvancesAndPauses() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        let source = try XCTUnwrap(Bundle.main.url(forResource: "TestTone", withExtension: "wav"))
        await library.importAudio([source])
        let track = try XCTUnwrap(library.tracks.first)
        let engine = PlaybackStore(library: library)
        engine.play(track, in: library.tracks)
        for _ in 0..<50 {
            if engine.position > 0.2 { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertNil(engine.error); XCTAssertTrue(engine.isPlaying); XCTAssertGreaterThan(engine.position, 0.2)
        engine.pause()
        try await Task.sleep(nanoseconds: 200_000_000)
        let paused = engine.position
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(engine.position, paused, accuracy: 0.12)
        engine.seek(1)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(engine.position, 1, accuracy: 0.2)
        engine.setSleep(minutes: 15); XCTAssertNotNil(engine.sleepDeadline)
        engine.setSleep(minutes: nil); XCTAssertNil(engine.sleepDeadline)
        engine.stop(); XCTAssertNil(engine.current); XCTAssertTrue(engine.queue.isEmpty)
    }
    @MainActor func testMissingFileFailsGracefully() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root), engine = PlaybackStore(library: library)
        let missing = Track(id: UUID(), title: "Missing", artist: "Test", album: "Test", audioFile: "missing.wav", duration: 1, importedAt: Date())
        engine.play(missing, in: [missing]); XCTAssertNotNil(engine.error); XCTAssertNil(engine.current)
    }
}
