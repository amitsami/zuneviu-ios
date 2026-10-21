import Foundation
import Combine

enum AudioQuality: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, best
    var id: String { rawValue }
    var title: String { switch self { case .low: return "Low · ≤64 kbps"; case .medium: return "Medium · ≤128 kbps"; case .high: return "High · ≤320 kbps"; case .best: return "Best available" } }
    var ceiling: Int { switch self { case .low: return 64_000; case .medium: return 128_000; case .high: return 320_000; case .best: return .max } }
}
struct NativePreferences: Codable, Equatable {
    var audioQualityWifi: AudioQuality = .best
    var audioQualityCellular: AudioQuality = .medium
    var downloadQuality: AudioQuality = .best
    var wifiOnlyDownloads = true
    var cellularStreamingAllowed = true
    var localRecommendations = true
    var dontRepeatSuggestions = false
    var recordListeningHistory = true
    var reduceAnimation = false
    var reduceDynamicBlur = false
    var liquidGlass = true
    var hideVolumeBar = false
    var hideSongStatus = false
    var fullBleedArtwork = true
    var syncedLyrics = true
    var lyricsBlur = false
    var autoplay = true
    var saavnEnabled = false
    var imageCacheBudgetMiB = 48
}
@MainActor final class PreferenceStore: ObservableObject {
    static let shared = PreferenceStore()
    @Published var values: NativePreferences { didSet { persist() } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let baseline = (try? JSONEncoder().encode(NativePreferences())).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let saved = defaults.data(forKey: "nativePreferencesV1").flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let merged = baseline.merging(saved) { _, saved in saved }
        values = (try? JSONSerialization.data(withJSONObject: merged)).flatMap { try? JSONDecoder().decode(NativePreferences.self, from: $0) } ?? NativePreferences()
    }
    private func persist() { if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: "nativePreferencesV1") } }
}
