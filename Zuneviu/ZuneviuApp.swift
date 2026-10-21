import SwiftUI

@main struct ZuneviuApp: App {
    @StateObject private var library: LibraryStore
    @StateObject private var playback: PlaybackStore
    @StateObject private var preferences: PreferenceStore
    @StateObject private var discovery: DiscoveryStore
    @StateObject private var downloads: DownloadManager
    @Environment(\.scenePhase) private var phase
    @AppStorage("theme") private var theme = "dark"
    init() {
        let store: LibraryStore
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            store = DebugFixture.makeLibrary()
        } else if ProcessInfo.processInfo.arguments.contains("--live-ui-testing") {
            UserDefaults.standard.set(true, forKey: "hasSeenPortNotice")
            store = LibraryStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("LiveAcceptance-" + UUID().uuidString))
        } else { store = LibraryStore() }
        #else
        store = LibraryStore()
        #endif
        _library = StateObject(wrappedValue: store)
        let prefs: PreferenceStore
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let defaults = UserDefaults(suiteName: "Zuneviu-fixture-" + UUID().uuidString)!
            prefs = PreferenceStore(defaults: defaults)
        } else { prefs = PreferenceStore.shared }
        #else
        prefs = PreferenceStore.shared
        #endif
        let taste = DiscoveryStore(root: store.root, preferences: prefs)
        _preferences = StateObject(wrappedValue: prefs)
        _discovery = StateObject(wrappedValue: taste)
        _downloads = StateObject(wrappedValue: DownloadManager(library: store, preferences: prefs, network: NetworkStatus.shared))
        _playback = StateObject(wrappedValue: PlaybackStore(library: store, preferences: prefs, discovery: taste))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(library).environmentObject(playback).environmentObject(playback.clock)
                .environmentObject(preferences).environmentObject(discovery).environmentObject(downloads).environmentObject(NetworkStatus.shared)
                .modifier(AppAccessibilitySettings())
                .task(id: preferences.values.imageCacheBudgetMiB) { await ArtworkLoader.shared.setMemoryBudget(preferences.values.imageCacheBudgetMiB) }
                .tint(.pink).preferredColorScheme(theme == "system" ? nil : (theme == "light" ? .light : .dark))
                .onChange(of: phase) { newPhase in if newPhase != .active { library.save() } }
        }
    }
}
