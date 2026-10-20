import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    @State private var tab = 0
    @State private var importing = false
    @State private var showingPlayer = false
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenPortNotice")
    var body: some View {
        Group {
            switch tab {
            case 1: NavigationStack { ExploreView().toolbar { settingsButton } }
            case 2: NavigationStack { LibraryView(importAction: { importing = true }).toolbar { settingsButton } }
            default: NavigationStack {
                HomeView(importAction: { importing = true })
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Brand() }; settingsButton }
            }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                if let track = playback.current { miniPlayer(track) }
                HStack(spacing: 6) {
                    tabButton("Home", icon: "house.fill", value: 0)
                    tabButton("Explore", icon: "safari", value: 1)
                    tabButton("Library", icon: "square.stack.fill", value: 2)
                    Button { showingSearch = true } label: { Image(systemName: "magnifyingglass").font(.title2).frame(width: 56, height: 54) }
                        .accessibilityLabel("Search music")
                }.padding(5).background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.primary.opacity(0.18), lineWidth: 0.5))
            }.padding(.horizontal, 16).padding(.vertical, 8).background(.bar)
        }
        .sheet(isPresented: $showingPlayer) { NowPlayingView() }
        .sheet(isPresented: $showingSettings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $showingSearch) { NavigationStack { SearchView() } }
        .sheet(isPresented: $showWelcome) {
            VStack(alignment: .leading, spacing: 20) {
                Brand()
                Text("iOS development build").font(.largeTitle.bold())
                Text("This is an initial native iOS port, not the full Android feature set.").font(.title3.weight(.semibold))
                Text("Start by importing your music. Local playback, favorites, playlists and LRC lyrics are implemented. Streaming catalogs, Google/Spotify sign-in, online downloads and Android audio effects have not been ported.")
                Text("This development port requires build and device validation before production use.").foregroundStyle(.secondary)
                Button("Continue to library") {
                    UserDefaults.standard.set(true, forKey: "hasSeenPortNotice"); showWelcome = false
                }.buttonStyle(.borderedProminent)
            }.padding(28).presentationDetents([.large]).interactiveDismissDisabled()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await library.importAudio(urls) }
            case .failure(let error): library.error = error.localizedDescription
            }
        }
        .overlay { if library.isImporting { ProgressView("Importing music…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
        .alert("Something needs attention", isPresented: Binding(get: { library.error != nil || playback.error != nil }, set: { if !$0 { library.error = nil; playback.error = nil } })) {
            Button("OK") { library.error = nil; playback.error = nil }
        } message: { Text(library.error ?? playback.error ?? "") }
    }
    @ToolbarContentBuilder private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: { Image(systemName: "gearshape.fill").frame(width: 44, height: 44) }.accessibilityLabel("Settings")
        }
    }
    private func tabButton(_ title: String, icon: String, value: Int) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 3) { Image(systemName: icon).font(.title3); Text(title).font(.caption) }
                .frame(maxWidth: .infinity).frame(height: 54)
                .foregroundStyle(tab == value ? Color.primary : Color.secondary)
                .background { if tab == value { Capsule().fill(.primary.opacity(0.08)) } }
        }.buttonStyle(.plain).accessibilityAddTraits(tab == value ? [.isSelected] : [])
    }
    private func miniPlayer(_ track: Track) -> some View {
        HStack(spacing: 8) {
            Button { showingPlayer = true } label: {
                HStack(spacing: 10) {
                    Artwork(track: track, radius: 8).frame(width: 43, height: 43)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.subheadline.bold()).lineLimit(1)
                        Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }.buttonStyle(.plain).accessibilityLabel("Now playing: \(track.title)")
            Button { playback.toggle() } label: { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }
                .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
            Button { playback.next() } label: { Image(systemName: "forward.fill").frame(width: 44, height: 44) }.accessibilityLabel("Next track")
        }.padding(7).background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.primary.opacity(0.2), lineWidth: 0.5))
    }
}

struct HomeView: View {
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
                    Button("Import more music", systemImage: "plus") { importAction() }.buttonStyle(.bordered).padding(.horizontal)
                }
            }.padding(.vertical, 18)
        }.navigationTitle("Listen Now")
    }
    private func shelf(_ title: String, subtitle: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.title2.bold()); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }.padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
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

struct ExploreView: View {
    @EnvironmentObject var library: LibraryStore
    private var artists: [String] { Array(Set(library.tracks.map(\.artist))).sorted() }
    private var albums: [String] { Array(Set(library.tracks.map(\.album))).sorted() }
    var body: some View {
        List {
            Section {
                NavigationLink { SearchView() } label: { Label("Search your music", systemImage: "magnifyingglass") }
            }
            Section("Artists") {
                ForEach(artists, id: \.self) { artist in
                    NavigationLink { TrackCollection(title: artist, tracks: library.tracks.filter { $0.artist == artist }) } label: { Label(artist, systemImage: "person.crop.circle") }
                }
                if artists.isEmpty { Text("Import music to explore your artists and albums.").foregroundStyle(.secondary) }
            }
            Section("Albums") {
                ForEach(albums, id: \.self) { album in
                    NavigationLink { TrackCollection(title: album, tracks: library.tracks.filter { $0.album == album }) } label: { Label(album, systemImage: "square.stack") }
                }
            }
            Section("Streaming discovery") { Text("Android's online recommendations and provider catalogs are not connected in this development build.").font(.subheadline).foregroundStyle(.secondary) }
        }.navigationTitle("Explore")
    }
}

struct SearchView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var query = ""
    private var results: [Track] {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? library.tracks : library.tracks.filter { [$0.title, $0.artist, $0.album].contains { $0.localizedCaseInsensitiveContains(key) } }
    }
    var body: some View {
        List {
            ForEach(results) { TrackRow(track: $0, context: results) }
            if results.isEmpty { ContentUnavailableView.search(text: query) }
        }.listStyle(.plain).navigationTitle("Search").searchable(text: $query, prompt: "Songs, artists, albums")
    }
}
