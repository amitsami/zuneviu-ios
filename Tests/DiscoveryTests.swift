import XCTest
@testable import Zuneviu

final class DiscoveryTests: XCTestCase {
    private func song(_ number: Int) -> Track {
        Track(id: UUID(), title: "Song \(number)", artist: "Fixture", album: "", audioFile: "", duration: 60, importedAt: Date(), videoID: String(format: "fixture%04d", number))
    }
    @MainActor private func preferences() -> PreferenceStore { PreferenceStore(defaults: UserDefaults(suiteName: UUID().uuidString)!) }
    @MainActor func testQualificationClampsDeltasAndPersistsEightSeeds() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let prefs = preferences(), store = DiscoveryStore(root: root, preferences: preferences())
        let first = song(1)
        store.record(first, seconds: .nan); store.record(first, seconds: -1)
        store.record(first, seconds: 1000)
        XCTAssertTrue(store.seeds.isEmpty, "A seek or giant tick must not qualify a song")
        for _ in 0..<3 { store.record(first, seconds: 5) }
        XCTAssertEqual(store.seeds.map(\.id), [first.id])
        for n in 2...10 { let track = song(n); for _ in 0..<4 { store.record(track, seconds: 5) } }
        XCTAssertEqual(store.seeds.count, 8)
        XCTAssertFalse(store.seeds.contains { $0.id == first.id })
        XCTAssertEqual(DiscoveryStore(root: root, preferences: prefs).seeds, store.seeds)
        store.clear(); XCTAssertTrue(DiscoveryStore(root: root, preferences: prefs).seeds.isEmpty)
    }
    func testRoundRobinExcludesSeedsHistoryInvalidAndDuplicates() {
        let seed = song(1), a = song(2), b = song(3), c = song(4), heard = song(5)
        var invalid = song(6); invalid.videoID = "bad"
        let result = LocalDiscoveryPolicy.candidates(seeds: [seed], queues: [[seed, a, c, invalid], [b, a, heard]], excluded: [heard.id])
        XCTAssertEqual(result.map(\.id), [b.id, a.id, c.id])
    }
    @MainActor func testHistoryAndDiscoveryOptOutPreventsQualification() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let prefs = preferences(), store = DiscoveryStore(root: root, preferences: preferences())
        // Test each controlling preference with the same injected store.
        let controlled = DiscoveryStore(root: root, preferences: prefs)
        prefs.values.recordListeningHistory = false
        let track = song(1); for _ in 0..<8 { controlled.record(track, seconds: 5) }
        XCTAssertTrue(controlled.seeds.isEmpty)
        prefs.values.recordListeningHistory = true; prefs.values.localRecommendations = false
        for _ in 0..<8 { controlled.record(track, seconds: 5) }
        XCTAssertTrue(controlled.seeds.isEmpty); XCTAssertTrue(store.seeds.isEmpty)
    }
    @MainActor func testRefreshPersistsFixtureSuggestionsAndResetPreventsLateRestore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let prefs = preferences(), store = DiscoveryStore(root: root, preferences: preferences())
        let seed = song(1), candidate = song(2)
        for _ in 0..<4 { store.record(seed, seconds: 5) }
        await store.refresh(loader: { _ in [candidate] })
        XCTAssertEqual(store.suggestions, [candidate]); XCTAssertFalse(store.loading)
        XCTAssertEqual(DiscoveryStore(root: root, preferences: prefs).suggestions, [candidate])
        let work = Task { await store.refresh(loader: { _ in try await Task.sleep(nanoseconds: 100_000_000); return [candidate] }) }
        try await Task.sleep(nanoseconds: 20_000_000)
        store.clear(); await work.value
        XCTAssertTrue(store.suggestions.isEmpty); XCTAssertFalse(store.loading)
    }
    @MainActor func testPreferencesPersistWithoutSharingTestDefaults() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferenceStore(defaults: defaults)
        store.values.audioQualityWifi = .high; store.values.wifiOnlyDownloads = false; store.values.reduceAnimation = true
        let reopened = PreferenceStore(defaults: defaults)
        XCTAssertEqual(reopened.values, store.values)
        XCTAssertEqual(AudioQuality.low.ceiling, 64_000)
        XCTAssertTrue(reopened.values.reduceAnimation)
    }
}
