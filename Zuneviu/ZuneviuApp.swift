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
        } else { store = LibraryStore() }
        #else
        store = LibraryStore()
        #endif
        _library = StateObject(wrappedValue: store)
        _playback = StateObject(wrappedValue: PlaybackStore(library: store))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(library).environmentObject(playback)
                .tint(.pink).preferredColorScheme(theme == "system" ? nil : (theme == "light" ? .light : .dark))
                .onChange(of: phase) { _, newPhase in if newPhase != .active { library.save() } }
        }
    }
}
