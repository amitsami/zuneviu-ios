import XCTest
import Combine
import UIKit
@testable import Zuneviu

final class OptimizationTests: XCTestCase {
    func testFooterSafeAreaMath() {
        XCTAssertEqual(DockLayout.bottomLift(safeArea: 34), 10)
        XCTAssertEqual(DockLayout.bottomLift(safeArea: 24), 4)
        XCTAssertEqual(DockLayout.bottomLift(safeArea: 0), 0)
        XCTAssertEqual(DockLayout.bottomLift(safeArea: -1), 0)
        XCTAssertGreaterThanOrEqual(DockLayout.baseHeight - 8, 44)
    }
    @MainActor func testClockIgnoresUnchangedValues() {
        let clock = PlaybackClock()
        var updates = 0
        let subscription = clock.objectWillChange.sink { updates += 1 }
        clock.setPosition(0); clock.setDuration(0)
        XCTAssertEqual(updates, 0)
        clock.setPosition(1); clock.setDuration(100)
        XCTAssertEqual(updates, 2)
        clock.setPosition(1); clock.setDuration(100)
        XCTAssertEqual(updates, 2)
        withExtendedLifetime(subscription) {}
    }
    @MainActor func testListeningTimeBatchesNotificationsWithoutLosingSeconds() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        var updates = 0
        let subscription = library.objectWillChange.sink { updates += 1 }
        for _ in 0..<30 { library.addListening(0.5) }
        library.addListening(.nan); library.addListening(.infinity); library.addListening(-1)
        XCTAssertEqual(updates, 0, "Clock ticks must not redraw every library observer")
        XCTAssertTrue(library.save())
        XCTAssertEqual(updates, 1)
        XCTAssertEqual(LibraryStore(root: root).snapshot.listenedSeconds, 15, accuracy: 0.001)
        XCTAssertTrue(library.save())
        XCTAssertEqual(updates, 1, "Saving unchanged listening time must not republish")
        XCTAssertEqual(LibraryStore(root: root).snapshot.listenedSeconds, 15, accuracy: 0.001)
        withExtendedLifetime(subscription) {}
    }
    @MainActor func testRealPlaybackClockDoesNotInvalidateLibraryOrPlayerGraph() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        await library.importAudio([try XCTUnwrap(Bundle.main.url(forResource: "TestTone", withExtension: "wav"))])
        let engine = PlaybackStore(library: library)
        defer { engine.stop() }
        engine.play(try XCTUnwrap(library.tracks.first), in: library.tracks)
        for _ in 0..<40 {
            if engine.position > 0.5 { break }
            try await Task.sleep(nanoseconds: 100000000)
        }
        XCTAssertTrue(engine.isPlaying)
        var clockUpdates = 0, playerUpdates = 0, libraryUpdates = 0
        let subscriptions = [
            engine.clock.objectWillChange.sink { clockUpdates += 1 },
            engine.objectWillChange.sink { playerUpdates += 1 },
            library.objectWillChange.sink { libraryUpdates += 1 }
        ]
        try await Task.sleep(nanoseconds: 2000000000)
        XCTAssertGreaterThanOrEqual(clockUpdates, 3)
        XCTAssertEqual(playerUpdates, 0, "Position updates must not rebuild navigation/footer")
        XCTAssertEqual(libraryUpdates, 0, "Listening increments must not rebuild library every tick")
        withExtendedLifetime(subscriptions) {}
    }
    @MainActor func testArtworkDownsamplesAndReusesDecodedImage() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1600), format: format).image { context in
            UIColor.systemPink.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1600))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTUnwrap(image.pngData()).write(to: url)
        let first = try await XCTUnwrapAsync { await ArtworkLoader.shared.image(url, pixels: 128) }
        XCTAssertLessThanOrEqual(first.cgImage?.width ?? .max, 128)
        XCTAssertLessThanOrEqual(first.cgImage?.height ?? .max, 128)
        let second = await ArtworkLoader.shared.image(url, pixels: 128)
        XCTAssertTrue(first === second, "Cache must reuse the decoded image")
    }
    func testBadArtworkFailsGracefully() async {
        let result = await ArtworkLoader.shared.image(URL(fileURLWithPath: "/nonexistent-artwork.png"))
        XCTAssertNil(result)
    }
    @MainActor private func XCTUnwrapAsync<T>(_ operation: () async -> T?) async throws -> T {
        let value = await operation(); return try XCTUnwrap(value)
    }
}
