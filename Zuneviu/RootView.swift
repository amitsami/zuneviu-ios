import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var tab = 0
    @State private var visitedTabs: Set<Int> = [0]
    @State private var importing = false
    @State private var showingPlayer = false
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenPortNotice")
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    if visitedTabs.contains(index) {
                        page(index)
                            .opacity(tab == index ? 1 : 0)
                            .allowsHitTesting(tab == index)
                            .accessibilityHidden(tab != index)
                            .zIndex(tab == index ? 1 : 0)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GlassFooter(selection: $tab, select: { value in
                    visitedTabs.insert(value); tab = value
                }, openSearch: { showingSearch = true }, openPlayer: { showingPlayer = true })
                    .padding(.bottom, geometry.safeAreaInsets.bottom == 0 ? 6 : -DockLayout.bottomLift(safeArea: geometry.safeAreaInsets.bottom))
            }
        }
        .sheet(isPresented: $showingPlayer) { NowPlayingView() }
        .sheet(isPresented: $showingSettings) { CompatibleNavigation { SettingsView() } }
        .sheet(isPresented: $showingSearch) { CompatibleNavigation { SearchView() } }
        .sheet(isPresented: $showWelcome) {
            VStack(alignment: .leading, spacing: 20) {
                Brand()
                Text("iOS development build").font(.largeTitle.bold())
                Text("This is an initial native iOS port, not the full Android feature set.").font(.title3.weight(.semibold))
                Text("Online catalog, search and on-device stream extraction are now integrated for validation. Local music still works offline. Google/Spotify sign-in, account sync and Android audio effects are not yet ported. Streaming may fail where the provider requires authentication or blocks extraction.")
                Text("This development port requires build and device validation before production use.").foregroundStyle(.secondary)
                Button("Continue") {
                    UserDefaults.standard.set(true, forKey: "hasSeenPortNotice"); showWelcome = false
                }.buttonStyle(.borderedProminent)
            }.padding(28).interactiveDismissDisabled()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await library.importAudio(urls) }
            case .failure(let error): library.error = error.localizedDescription
            }
        }
        .overlay { if library.isImporting { ProgressView("Importing music…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
    }
    @ViewBuilder private func page(_ index: Int) -> some View {
        CompatibleNavigation {
            switch index {
            case 1: ExploreView().toolbar { settingsButton }
            case 2: LibraryView(importAction: { importing = true }).toolbar { settingsButton }
            default:
                HomeView(importAction: { importing = true })
                    .toolbar { ToolbarItem(placement: .navigationBarLeading) { Brand() }; settingsButton }
            }
        }
    }
    @ToolbarContentBuilder private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showingSettings = true } label: { Image(systemName: "gearshape.fill").frame(width: 44, height: 44) }.accessibilityLabel("Settings")
        }
    }
}

struct LocalHomeView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    let importAction: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if library.tracks.isEmpty { EmptyLibrary(importAction: importAction) }
                else {
                    shelf("Made for you", subtitle: "From your on-device listening", tracks: library.recent.isEmpty ? Array(library.tracks.prefix(12)) : library.recent)
                    if !library.favorites.isEmpty { shelf("Your favorites", subtitle: "Songs you love", tracks: library.favorites) }
                    shelf("Recently added", subtitle: "On this device", tracks: Array(library.tracks.reversed().prefix(12)))
                    IconButton("Import more music", systemImage: "plus") { importAction() }.buttonStyle(.bordered).padding(.horizontal)
                }
            }.padding(.vertical, 18)
        }.navigationTitle("Listen Now")
    }
    private func shelf(_ title: String, subtitle: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.title2.bold()); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }.padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(tracks) { track in
                        Button { playback.play(track, in: tracks) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Artwork(track: track).frame(width: title == "Made for you" ? 245 : 155, height: title == "Made for you" ? 285 : 155)
                                Text(track.title).font(.headline).lineLimit(1)
                                Text(track.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }.frame(width: title == "Made for you" ? 245 : 155, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }
        }
    }
}

