import XCTest
import AVFoundation
@testable import Zuneviu

// Deliberately separate from fixture tests. These MUST pass before describing
// online playback as working. A restricted CI IP is a test failure, not a pass.
final class LiveProviderTests: XCTestCase {
    func testLiveCatalogSearchAndHome() async throws {
        let page = try await MusicCatalog.shared.search("The Weeknd Starboy")
        XCTAssertFalse(page.items.compactMap(\.track).isEmpty, "Real catalog returned no playable song rows")
        XCTAssertTrue(page.items.contains { $0.title.localizedCaseInsensitiveContains("Starboy") })
        let home = try await MusicCatalog.shared.home()
        XCTAssertFalse(home.isEmpty, "Real home shelves are empty")
        XCTAssertTrue(home.contains { !$0.items.isEmpty })
    }
    @MainActor func testActualOnlineAudioAdvancesPausesSeeksAndNext() async throws {
        let page = try await MusicCatalog.shared.search("The Weeknd Starboy")
        let songs = Array(page.items.compactMap(\.track).prefix(3))
        let first = try XCTUnwrap(songs.first)
        XCTAssertGreaterThan(songs.count, 1)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root), engine = PlaybackStore(library: library)
        defer { engine.stop() }
        engine.play(first, in: songs)
        for _ in 0..<180 {
            if engine.error != nil || engine.position > 1 { break }
            try await Task.sleep(nanoseconds: 500000000)
        }
        XCTAssertNil(engine.error, "Real online stream failed, not a fixture failure")
        XCTAssertTrue(engine.isPlaying); XCTAssertGreaterThan(engine.position, 1)
        guard engine.isPlaying else { XCTFail("Online playback never started"); return }
        engine.pause(); try await Task.sleep(nanoseconds: 300000000)
        let paused = engine.position
        try await Task.sleep(nanoseconds: 800000000)
        XCTAssertEqual(engine.position, paused, accuracy: 0.2)
        engine.seek(15); try await Task.sleep(nanoseconds: 2000000000)
        XCTAssertEqual(engine.position, 15, accuracy: 1)
        engine.next()
        for _ in 0..<180 {
            if engine.error != nil || (engine.current?.id == songs[1].id && engine.position > 0.5) { break }
            try await Task.sleep(nanoseconds: 500000000)
        }
        XCTAssertNil(engine.error); XCTAssertEqual(engine.current?.id, songs[1].id)
        XCTAssertGreaterThan(engine.position, 0.5)
    }
}
