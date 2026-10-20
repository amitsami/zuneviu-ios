import XCTest
@testable import Zuneviu

final class CatalogTests: XCTestCase {
    private func row(id: String = "3_g2un5M350") -> [String: Any] {
        ["musicResponsiveListItemRenderer": [
            "playlistItemData": ["videoId": id],
            "flexColumns": [
                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Starboy (feat. Daft Punk)"]]]]],
                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Song • "], ["text": "The Weeknd", "navigationEndpoint": ["browseEndpoint": ["browseId": "UC_TEST"]]], ["text": " • 3:50"]]]]]
            ],
            "thumbnail": ["musicThumbnailRenderer": ["thumbnail": ["thumbnails": [["url": "https://example.com/cover.jpg", "width": 300]]]]]
        ]]
    }
    func testRealSearchRendererShapePreservesMetadata() throws {
        let item = try XCTUnwrap(CatalogParser.items(row()).first)
        let song = try XCTUnwrap(item.track)
        XCTAssertEqual(song.videoID, "3_g2un5M350")
        XCTAssertEqual(song.title, "Starboy (feat. Daft Punk)")
        XCTAssertEqual(song.artist, "The Weeknd")
        XCTAssertEqual(song.duration, 230)
        XCTAssertEqual(song.artworkURL, "https://example.com/cover.jpg")
        XCTAssertEqual(song.artistBrowseID, "UC_TEST")
        XCTAssertFalse(song.isLocal)
    }
    func testDeduplicatesWithoutReorderingSongs() {
        let items = CatalogParser.items([row(), row(id: "aqz-KE-bpKQ"), row()])
        XCTAssertEqual(items.compactMap { $0.track?.videoID }, ["3_g2un5M350","aqz-KE-bpKQ"])
    }
    func testStableTrackIdentityAcrossSearches() throws {
        let first = try XCTUnwrap(CatalogParser.items(row()).first?.track)
        let second = try XCTUnwrap(CatalogParser.items(row()).first?.track)
        XCTAssertEqual(first.id, second.id)
        XCTAssertNotEqual(first.id, CatalogParser.stableID("youtube:aqz-KE-bpKQ"))
    }
    func testRejectsInvalidVideoIDs() { XCTAssertTrue(CatalogParser.items(row(id: "../invalid")).isEmpty) }
    func testAlbumIsNotMistakenForTrack() throws {
        let item: [String: Any] = ["musicTwoRowItemRenderer": ["title": ["runs": [["text":"Starboy"]]], "navigationEndpoint": ["browseEndpoint": ["browseId":"MPRE_TEST"]], "overlay": ["musicItemThumbnailOverlayRenderer": ["content": ["musicPlayButtonRenderer": ["playNavigationEndpoint": ["watchEndpoint": ["videoId":"3_g2un5M350"]]]]]]]]
        let result = try XCTUnwrap(CatalogParser.items(item).first)
        XCTAssertEqual(result.browseID, "MPRE_TEST"); XCTAssertNil(result.track)
    }
    func testHomeShelfAndContinuation() throws {
        let json: [String: Any] = ["musicCarouselShelfRenderer": ["header": ["musicCarouselShelfBasicHeaderRenderer": ["title": ["runs": [["text":"Quick picks"]]]]], "contents": [row()]], "continuations": [["nextContinuationData": ["continuation":"next-page"]]]]
        let shelf = try XCTUnwrap(CatalogParser.shelves(json).first)
        XCTAssertEqual(shelf.title, "Quick picks"); XCTAssertEqual(shelf.items.count, 1)
        XCTAssertEqual(CatalogParser.continuation(json), "next-page")
    }
    func testDynamicShellConfiguration() {
        XCTAssertEqual(MusicCatalog.capture(#""INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)""#, #"ytcfg.set({"INNERTUBE_CLIENT_VERSION":"1.current.00"});"#), "1.current.00")
        XCTAssertNil(MusicCatalog.capture(#""INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)""#, "consent page"))
    }
    func testOldLocalLibraryDecodesWithoutNewFields() throws {
        let json = #"{"id":"B7A166DF-A636-420F-A7F8-39943782D351","title":"Old song","artist":"Test","album":"Local Music","audioFile":"old.mp3","duration":30,"importedAt":0}"#
        let song = try JSONDecoder().decode(Track.self, from: Data(json.utf8))
        XCTAssertTrue(song.isLocal); XCTAssertNil(song.videoID)
    }
    @MainActor func testRemoteFavoritesAndPlaylistSurviveRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(root: root)
        let track = try XCTUnwrap(CatalogParser.items(row()).first?.track)
        library.remember(track); library.remember(track)
        library.toggleFavorite(track.id); library.createPlaylist("Online songs")
        library.add(track.id, to: try XCTUnwrap(library.snapshot.playlists.first?.id))
        let reopened = LibraryStore(root: root)
        XCTAssertEqual(reopened.tracks.count, 1); XCTAssertEqual(reopened.favorites.first?.videoID, track.videoID)
        XCTAssertEqual(reopened.snapshot.playlists.first?.trackIDs, [track.id]); XCTAssertTrue(reopened.onDevice.isEmpty)
        reopened.remove(track.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path)); XCTAssertTrue(reopened.tracks.isEmpty)
    }
}
