import XCTest
@testable import Zuneviu

final class LibraryTests: XCTestCase {
    @MainActor func testPlaylistPersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root)
        store.createPlaylist("   Road trip   "); store.createPlaylist("  ")
        XCTAssertEqual(store.snapshot.playlists.count, 1)
        XCTAssertEqual(store.snapshot.playlists.first?.name, "Road trip")
        let trackID = UUID(), playlistID = try XCTUnwrap(store.snapshot.playlists.first?.id)
        store.add(trackID, to: playlistID); store.add(trackID, to: playlistID)
        XCTAssertEqual(store.snapshot.playlists.first?.trackIDs, [trackID])
        let reopened = LibraryStore(root: root)
        XCTAssertEqual(reopened.snapshot.playlists, store.snapshot.playlists)
    }
    @MainActor func testFavoriteTogglesAndPersists() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root), id = UUID()
        store.toggleFavorite(id); XCTAssertTrue(LibraryStore(root: root).snapshot.favorites.contains(id))
        store.toggleFavorite(id); XCTAssertFalse(LibraryStore(root: root).snapshot.favorites.contains(id))
    }
    @MainActor func testCorruptManifestIsNotOverwritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("library.json"), original = Data("not-json".utf8)
        try original.write(to: file)
        let store = LibraryStore(root: root)
        XCTAssertNotNil(store.error); XCTAssertFalse(store.storageReady)
        XCTAssertFalse(store.save()); XCTAssertEqual(try Data(contentsOf: file), original)
    }
    @MainActor func testImportPlaybackMetadataAndDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: inputFolder) }
        try FileManager.default.createDirectory(at: inputFolder, withIntermediateDirectories: true)
        let bundled = try XCTUnwrap(Bundle.main.url(forResource: "TestTone", withExtension: "wav"))
        let original = inputFolder.appendingPathComponent("Original.wav")
        try FileManager.default.copyItem(at: bundled, to: original)
        let store = LibraryStore(root: root)
        await store.importAudio([original])
        XCTAssertNil(store.error)
        let track = try XCTUnwrap(store.tracks.first)
        XCTAssertGreaterThan(track.duration, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.file(track.audioFile).path))
        store.toggleFavorite(track.id); store.createPlaylist("A")
        store.add(track.id, to: try XCTUnwrap(store.snapshot.playlists.first?.id)); store.recordPlay(track.id)
        let lyrics = inputFolder.appendingPathComponent("lyrics.lrc")
        try Data("[00:01.00]Hello".utf8).write(to: lyrics)
        store.importLyrics(lyrics, for: track.id)
        XCTAssertEqual(store.lyricText(track.id), "[00:01.00]Hello")
        store.remove(track.id)
        XCTAssertTrue(store.tracks.isEmpty); XCTAssertTrue(store.snapshot.favorites.isEmpty)
        XCTAssertTrue(store.snapshot.history.isEmpty); XCTAssertTrue(store.snapshot.playlists[0].trackIDs.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.file(track.audioFile).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(LibraryStore(root: root).tracks.isEmpty)
    }
    @MainActor func testInvalidAudioDoesNotEnterLibrary() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let input = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: input) }
        try Data("not audio".utf8).write(to: input)
        let store = LibraryStore(root: root)
        await store.importAudio([input]); XCTAssertTrue(store.tracks.isEmpty); XCTAssertNotNil(store.error)
    }
}
