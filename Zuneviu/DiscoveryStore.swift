import Foundation
import Combine

// Port of Android LocalDiscoveryPolicy: 20 seconds qualified listening, eight
// device-local seeds, round-robin distinct results, never recommend the seeds.
// Extended explicitly for opt-in JioSaavn artist-search suggestions on iOS.
enum LocalDiscoveryPolicy {
    static let qualifyingSeconds: Double = 20
    static let maximumSeeds = 8
    static func eligible(_ track: Track) -> Bool {
        if let id = track.videoID, id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil { return true }
        return track.saavnID?.range(of: #"^[A-Za-z0-9_-]{1,32}$"#, options: .regularExpression) != nil
    }
    static func candidates(seeds: [Track], queues: [[Track]], excluded: Set<UUID> = []) -> [Track] {
        let heard = Set(seeds.map(\.id)).union(excluded)
        var seen = Set<UUID>(), result: [Track] = []
        for index in 0..<(queues.map(\.count).max() ?? 0) {
            for queue in queues where index < queue.count {
                let track = queue[index]
                guard !heard.contains(track.id), !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      eligible(track), seen.insert(track.id).inserted else { continue }
                result.append(track)
                if result.count == 20 { return result }
            }
        }
        return result
    }
}
@MainActor final class DiscoveryStore: ObservableObject {
    @Published private(set) var seeds: [Track] = []
    @Published private(set) var suggestions: [Track] = []
    @Published private(set) var loading = false
    @Published private(set) var failure: String?
    private var listened: [UUID: Double] = [:]
    private var listeningOrder: [UUID] = []
    private var generation = UUID()
    private let root: URL
    private let preferences: PreferenceStore
    init(root: URL, preferences: PreferenceStore) {
        self.root = root; self.preferences = preferences
        if let data = try? Data(contentsOf: root.appendingPathComponent("discovery-seeds.json")), let tracks = try? JSONDecoder().decode([Track].self, from: data) { seeds = Array(tracks.prefix(8)) }
        if let data = try? Data(contentsOf: root.appendingPathComponent("discovery-cache.json")), let tracks = try? JSONDecoder().decode([Track].self, from: data) { suggestions = Array(tracks.prefix(20)) }
    }
    var cacheKey: String { seeds.map { $0.id.uuidString }.joined(separator: ",") }
    func record(_ track: Track, seconds: Double) {
        guard preferences.values.localRecommendations, preferences.values.recordListeningHistory,
              seconds.isFinite, seconds > 0, LocalDiscoveryPolicy.eligible(track),
              track.saavnID == nil || preferences.values.saavnEnabled else { return }
        let before = listened[track.id] ?? 0
        guard before < LocalDiscoveryPolicy.qualifyingSeconds else { return }
        let total = min(20, before + min(5, seconds))
        listened[track.id] = total
        if !listeningOrder.contains(track.id) { listeningOrder.append(track.id) }
        while listeningOrder.count > 32 { listened[ listeningOrder.removeFirst() ] = nil }
        guard total >= 20 else { return }
        generation = UUID()
        seeds = Array(([track] + seeds.filter { $0.id != track.id }).prefix(8))
        persist(seeds, name: "discovery-seeds.json")
    }
    func clear() {
        generation = UUID(); listened = [:]; listeningOrder = []; seeds = []; suggestions = []; failure = nil; loading = false
        for name in ["discovery-seeds.json", "discovery-cache.json"] { try? FileManager.default.removeItem(at: root.appendingPathComponent(name)) }
    }
    var visibleSuggestions: [Track] { suggestions.filter { $0.saavnID == nil || preferences.values.saavnEnabled } }
    func refresh(excluding: Set<UUID> = [], loader: @escaping @Sendable (Track) async throws -> [Track] = { track in
        return try await SourceRecommendations.related(track)
    }) async {
        guard preferences.values.localRecommendations, !seeds.isEmpty else { return }
        generation = UUID(); let token = generation; let snapshot = seeds.filter { $0.saavnID == nil || preferences.values.saavnEnabled }
        loading = true; failure = nil
        defer { if generation == token { loading = false } }
        var queues = Array(repeating: [Track](), count: snapshot.count)
        await withTaskGroup(of: (Int, [Track]).self) { group in
            for (index, track) in snapshot.enumerated() {
                group.addTask { (index, (try? await loader(track)) ?? []) }
            }
            for await (index, tracks) in group { queues[index] = tracks }
        }
        guard generation == token, !Task.isCancelled, preferences.values.localRecommendations else { return }
        loading = false
        let candidates = LocalDiscoveryPolicy.candidates(seeds: snapshot, queues: queues, excluded: excluding)
        guard !candidates.isEmpty else { failure = "New recommendations could not be loaded. Saved suggestions remain available."; return }
        suggestions = candidates; persist(candidates, name: "discovery-cache.json")
    }
    private func persist(_ tracks: [Track], name: String) {
        do { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); try JSONEncoder().encode(tracks).write(to: root.appendingPathComponent(name), options: .atomic) }
        catch { failure = "Could not save device-local discovery." }
    }
}
