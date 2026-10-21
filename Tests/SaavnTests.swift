import XCTest
@testable import Zuneviu

final class SaavnTests: XCTestCase {
    func testPublicURLFormatDecryptsKnownVectorAndRejectsGarbage() throws {
        // Independently generated with OpenSSL DES/ECB/PKCS7; not a live URL.
        let encoded = "ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDy/fXNEPWHltYAjO6vTHbzEEWXwMeLXyuQM6qnV0VD5oE="
        XCTAssertEqual(try SaavnService.decrypt(encoded), "https://aac.saavncdn.com/123/Song_96.mp4?token=fixture")
        XCTAssertThrowsError(try SaavnService.decrypt("not-base64"))
    }
    func testQualityCeilingAnd320CapabilityPreserveQuery() throws {
        let url = "https://aac.saavncdn.com/123/Song_96.mp4?token=fixture"
        XCTAssertEqual(try SaavnService.rendition(url, supports320: true, quality: .best).path, "/123/Song_320.mp4")
        XCTAssertEqual(try SaavnService.rendition(url, supports320: false, quality: .best).path, "/123/Song_96.mp4")
        XCTAssertEqual(try SaavnService.rendition(url, supports320: true, quality: .low).path, "/123/Song_48.mp4")
        XCTAssertEqual(try SaavnService.rendition(url, supports320: true, quality: .medium).query, "token=fixture")
        XCTAssertThrowsError(try SaavnService.rendition("https://evil.example/track_96.mp4", supports320: true, quality: .best))
        XCTAssertThrowsError(try SaavnService.rendition("http://aac.saavncdn.com/track_96.mp4", supports320: true, quality: .best))
    }
    func testSaavnTrackIdentityIsStableAndNotAYouTubeSubstitution() throws {
        let raw: [String: Any] = ["id": "original1", "title": "Song &amp; Artist", "image": "https://c.saavncdn.com/image150x150.jpg", "more_info": ["duration": "240", "album": "Album", "artistMap": ["primary_artists": [["name": "Artist"]]]]]
        let a = try XCTUnwrap(SaavnService.track(raw)), b = try XCTUnwrap(SaavnService.track(raw))
        XCTAssertEqual(a.id, b.id); XCTAssertEqual(a.saavnID, "original1"); XCTAssertNil(a.videoID)
        XCTAssertEqual(a.title, "Song & Artist"); XCTAssertEqual(a.artist, "Artist")
        XCTAssertEqual(a.duration, 240); XCTAssertTrue(a.hasOnlineSource); XCTAssertFalse(a.isLocal)
        XCTAssertNotEqual(a.id, CatalogParser.stableID("youtube:original1"))
    }
    @MainActor func testSourceIsOffByDefaultAndCannotQueueWhenDisabled() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let prefs = PreferenceStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertFalse(prefs.values.saavnEnabled)
        let library = LibraryStore(root: root)
        let manager = DownloadManager(library: library, preferences: prefs, network: NetworkStatus(initial: .wifi, monitor: false), resolver: { _, _ in XCTFail("Disabled source must not resolve"); throw MusicServiceError.noStream })
        let track = Track(id: UUID(), title: "Fixture", artist: "", album: "", audioFile: "", duration: 10, importedAt: Date(), saavnID: "fixture")
        manager.enqueue(track); XCTAssertTrue(manager.jobs.isEmpty)
        let engine = PlaybackStore(library: library, preferences: prefs)
        defer { engine.stop() }; engine.play(track, in: [track]); XCTAssertNotNil(engine.error); XCTAssertNil(engine.current)
    }
    @MainActor func testPreferencesMigrationKeepsExistingValuesWhenNewFieldsAreMissing() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(Data(#"{"audioQualityWifi":"high","wifiOnlyDownloads":false,"reduceAnimation":true}"#.utf8), forKey: "nativePreferencesV1")
        let store = PreferenceStore(defaults: defaults)
        XCTAssertEqual(store.values.audioQualityWifi, .high); XCTAssertFalse(store.values.wifiOnlyDownloads)
        XCTAssertTrue(store.values.reduceAnimation); XCTAssertFalse(store.values.saavnEnabled)
    }
}
