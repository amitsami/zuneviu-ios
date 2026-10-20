import XCTest
@testable import Zuneviu

final class ModelTests: XCTestCase {
    func testLRCTimestampsAndOrdering() {
        let lines = LRCParser.parse("[01:02.34]Second\n[00:01.5][00:03.250]Repeat\n[ar:Artist]\n")
        XCTAssertEqual(lines.map(\.text), ["Repeat", "Repeat", "Second"])
        XCTAssertEqual(lines[0].time, 1.5, accuracy: 0.001)
        XCTAssertEqual(lines[1].time, 3.25, accuracy: 0.001)
        XCTAssertEqual(lines[2].time, 62.34, accuracy: 0.001)
        XCTAssertEqual(Set(lines.map(\.id)).count, 3)
    }
    func testPlainLyricsProduceNoTimedLines() { XCTAssertTrue(LRCParser.parse("Plain lyrics\nAnother line").isEmpty) }
    func testMalformedLyricsDoNotCrash() { XCTAssertTrue(LRCParser.parse("[ar:me]\n[xx:yy]No\n[]").isEmpty) }
    func testBlankTimedLine() { XCTAssertEqual(LRCParser.parse("[00:12] ").first?.text, "") }
    func testClock() { XCTAssertEqual(clockText(125.9), "2:05"); XCTAssertEqual(clockText(-4), "0:00"); XCTAssertEqual(clockText(.nan), "0:00") }
    func testSnapshotRoundTrip() throws {
        let track = Track(id: UUID(), title: "Song", artist: "Artist", album: "Album", audioFile: "sample.wav", duration: 3, importedAt: Date())
        let snapshot = LibrarySnapshot(tracks: [track], favorites: [track.id], playlists: [Playlist(name: "Test", trackIDs: [track.id])])
        let result = try JSONDecoder().decode(LibrarySnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(result.tracks, snapshot.tracks); XCTAssertEqual(result.favorites, snapshot.favorites)
        XCTAssertEqual(result.playlists, snapshot.playlists)
    }
}
