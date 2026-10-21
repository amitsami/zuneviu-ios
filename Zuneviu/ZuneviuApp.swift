import SwiftUI

@main struct ZuneviuApp: App {
    @StateObject private var library: LibraryStore
    @StateObject private var playback: PlaybackStore
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
        _playback = StateObject(wrappedValue: PlaybackStore(library: store))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(library).environmentObject(playback).environmentObject(playback.clock)
                .modifier(AppAccessibilitySettings())
                .tint(.pink).preferredColorScheme(theme == "system" ? nil : (theme == "light" ? .light : .dark))
                .onChange(of: phase) { newPhase in if newPhase != .active { library.save() } }
        }
    }
}
