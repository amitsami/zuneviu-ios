import SwiftUI

struct HomeView: View {
    let importAction: () -> Void
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { LocalHomeView(importAction: importAction) }
        else { CatalogHomeView(explore: false) }
    }
}
struct ExploreView: View {
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { LocalExploreView() }
        else { CatalogHomeView(explore: true) }
    }
}
struct CatalogHomeView: View {
    @EnvironmentObject private var discovery: DiscoveryStore
    @EnvironmentObject private var preferences: PreferenceStore
    let explore: Bool
    @EnvironmentObject var library: LibraryStore
    @State private var shelves: [CatalogShelf] = []
    @State private var loading = false
    @State private var failure: String?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                AndroidPageHeading(title: explore ? "Explore" : "Listen Now", branded: !explore)
                if preferences.values.saavnEnabled {
                    RouteLink { SearchView(initialSource: "saavn") } label: { Label("Search JioSaavn", systemImage: "magnifyingglass").padding(.horizontal) }
                }
                if !explore {
                    if !library.recent.isEmpty { OnlineTrackShelf(title: "Listen again", subtitle: "From your listening", tracks: library.recent, hero: true) }
                    if preferences.values.localRecommendations, !discovery.visibleSuggestions.isEmpty {
                        OnlineTrackShelf(title: "Made for you", subtitle: "From your on-device listening", tracks: discovery.visibleSuggestions, hero: library.recent.isEmpty)
                    }
                    if !library.favorites.isEmpty { OnlineTrackShelf(title: "Your favorites", subtitle: "Songs you love", tracks: library.favorites) }
                    if preferences.values.localRecommendations, let failure = discovery.failure { Text(failure).font(.footnote).foregroundStyle(.secondary).padding(.horizontal) }
                }
                if loading && shelves.isEmpty { ProgressView("Loading music…").frame(maxWidth: .infinity).padding(50) }
                if let failure { ServiceFailure(message: failure) { Task { await refresh() } } }
                ForEach(Array(shelves.enumerated()), id: \.element.id) { index, shelf in
                    CatalogShelfView(shelf: shelf, hero: !explore && index == 0 && library.recent.isEmpty && discovery.visibleSuggestions.isEmpty)
                }
                if !loading && shelves.isEmpty && failure == nil {
                    EmptyStateView("No music returned", systemImage: "music.note", description: Text("Pull down to retry or search for a song."))
                }
            }.padding(.vertical, 18)
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline).background(Color(uiColor: .systemBackground))
        .refreshable { await refresh() }
        .task { if shelves.isEmpty { await refresh() } }
        .task(id: discovery.cacheKey + String(preferences.values.localRecommendations) + String(preferences.values.dontRepeatSuggestions) + String(preferences.values.saavnEnabled)) {
            if !explore { await discovery.refresh(excluding: preferences.values.dontRepeatSuggestions ? Set(library.snapshot.history) : []) }
        }
    }
    @MainActor private func refresh() async {
        guard !loading else { return }; loading = true; failure = nil
        defer { loading = false }
        do { shelves = try await MusicCatalog.shared.home(explore: explore) }
        catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}
struct ServiceFailure: View {
    var message: String
    var retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Could not load music", systemImage: "wifi.exclamationmark").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Button("Retry", action: retry).buttonStyle(.bordered)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal)
    }
}
struct CatalogShelfView: View {
    let shelf: CatalogShelf
    var hero = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AndroidSectionHeading(title: shelf.title.isEmpty ? "Discover" : shelf.title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    let queue = shelf.items.compactMap(\.track)
                    ForEach(shelf.items) { item in CatalogCard(item: item, context: queue, hero: hero) }
                }.padding(.horizontal)
            }
        }
    }
}
struct OnlineTrackShelf: View {
    var title: String
    var subtitle: String
    var tracks: [Track]
    var hero = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AndroidSectionHeading(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(tracks.prefix(15)) { track in
                        CatalogCard(item: CatalogItem(id: track.id.uuidString, title: track.title, subtitle: track.artist, artwork: track.artworkURL, track: track), context: tracks, hero: hero)
                    }
                }.padding(.horizontal)
            }
        }
    }
}
struct CatalogCard: View {
    @Environment(\.androidPageWidth) private var pageWidth
    @EnvironmentObject private var downloads: DownloadManager
    let item: CatalogItem
    let context: [Track]
    var hero = false
    @EnvironmentObject var playback: PlaybackStore
    var body: some View {
        Group {
            if let track = item.track { Button { playback.play(track, in: context) } label: { card }.buttonStyle(.plain).accessibilityLabel("Play \(track.title) by \(track.artist)")
                .contextMenu { if !track.isLocal { IconButton("Download", systemImage: "arrow.down.circle") { downloads.enqueue(track) } } } }
            else if let id = item.browseID { RouteLink { CatalogBrowseView(id: id, title: item.title, params: item.params) } label: { card }.buttonStyle(.plain) }
        }
    }
    @ViewBuilder private var cover: some View {
        if let track = item.track { Artwork(track: track, radius: hero ? 18 : 12) }
        else { CachedArtwork(url: item.artwork.flatMap(URL.init(string:))) }
    }
    private var card: some View {
        let width = hero ? AndroidDesign.heroWidth(pageWidth) : AndroidDesign.cardWidth
        return VStack(alignment: .leading, spacing: 7) {
            if hero {
                ZStack(alignment: .bottomLeading) {
                    cover.frame(width: width, height: width / 0.92).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.system(size: 20, weight: .bold)).lineLimit(1)
                        Text(item.track?.artist ?? item.subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.72)).lineLimit(2)
                    }.foregroundStyle(.white).padding(16)
                }.frame(width: width, height: width / 0.92).clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            } else {
                cover.frame(width: width, height: width).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                Text(item.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(item.track?.artist ?? item.subtitle).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
            }
        }.frame(width: width, alignment: .leading)
    }
}

struct CatalogBrowseView: View {
    let id: String
    let title: String
    var params: String?
    @EnvironmentObject var playback: PlaybackStore
    @State private var items: [CatalogItem] = []
    @State private var continuation: String?
    @State private var loading = false
    @State private var failure: String?
    private var tracks: [Track] { items.compactMap(\.track) }
    var body: some View {
        List {
            if !tracks.isEmpty { IconButton("Play all", systemImage: "play.fill") { playback.play(tracks[0], in: tracks) } }
            if loading && items.isEmpty { ProgressView("Loading…") }
            if let failure { ServiceFailure(message: failure) { Task { await load(more: false) } } }
            ForEach(items) { item in
                if let track = item.track { TrackRow(track: track, context: tracks) }
                else if let nextID = item.browseID, nextID != id {
                    RouteLink { CatalogBrowseView(id: nextID, title: item.title, params: item.params) } label: { Label(item.title, systemImage: "square.stack") }
                }
            }
            if continuation != nil { Button(loading ? "Loading…" : "Load more") { Task { await load(more: true) } }.disabled(loading) }
            if !loading && items.isEmpty && failure == nil { Text("No playable songs on this page.").foregroundStyle(.secondary) }
        }.listStyle(.plain).navigationTitle(title).navigationBarTitleDisplayMode(.large)
            .task { if items.isEmpty { await load(more: false) } }.refreshable { await load(more: false) }
    }
    @MainActor private func load(more: Bool) async {
        guard !loading else { return }; loading = true; failure = nil
        defer { loading = false }
        do {
            let page = try await MusicCatalog.shared.browse(id, params: params, continuation: more ? continuation : nil)
            if more { let seen = Set(items.map(\.id)); items += page.items.filter { !seen.contains($0.id) } } else { items = page.items }
            continuation = page.continuation
        } catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}
struct SearchView: View {
    var initialSource = "youtube"
    @State private var initializedSource = false
    @State private var searchRequestID = UUID()
    @EnvironmentObject var preferences: PreferenceStore
    @State private var source = "youtube"
    @EnvironmentObject var library: LibraryStore
    @State private var query = ""
    @State private var online = !ProcessInfo.processInfo.arguments.contains("--ui-testing")
    @State private var items: [CatalogItem] = []
    @State private var continuation: String?
    @State private var loading = false
    @State private var failure: String?
    private var localResults: [Track] {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? library.tracks : library.tracks.filter { [$0.title,$0.artist,$0.album].contains { $0.localizedCaseInsensitiveContains(key) } }
    }
    var body: some View {
        List {
            Picker("Search in", selection: $online) { Text("Online").tag(true); Text("Library").tag(false) }.pickerStyle(.segmented)
            if online {
                if preferences.values.saavnEnabled {
                    Picker("Catalog source", selection: $source) { Text("YouTube Music").tag("youtube"); Text("JioSaavn").tag("saavn") }.pickerStyle(.segmented).accessibilityIdentifier("search.source")
                }
                Text(source == "saavn" ? "JioSaavn results · No automatic recording substitution" : "YouTube Music results").font(.caption).foregroundStyle(.secondary)
                if loading { ProgressView("Searching music…") }
                if let failure { ServiceFailure(message: failure) { Task { await search(more: false) } } }
                ForEach(items) { item in
                    if let track = item.track { TrackRow(track: track, context: items.compactMap(\.track)) }
                }
                if continuation != nil { Button("Load more results") { Task { await search(more: true) } }.disabled(loading) }
                if !loading && items.isEmpty && failure == nil {
                    EmptyStateView(query.isEmpty ? "Find your next favorite" : "No results", systemImage: "magnifyingglass", description: Text(query.isEmpty ? "Search the online music catalog." : "Try another song or artist."))
                }
            } else {
                ForEach(localResults) { TrackRow(track: $0, context: localResults) }
                if localResults.isEmpty { EmptyStateView.search(text: query) }
            }
        }.listStyle(.plain).navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, artists, albums")
            .onAppear { if !initializedSource { source = initialSource; initializedSource = true } }
            .onChange(of: preferences.values.saavnEnabled) { enabled in if !enabled { source = "youtube" } }
            .task(id: query + String(online) + source) {
                guard online else { return }
                items = []; continuation = nil; failure = nil
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                do { try await Task.sleep(nanoseconds: 450000000); try Task.checkCancellation(); await search(more: false) } catch { }
            }
    }
    @MainActor private func search(more: Bool) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        let selectedSource = source
        searchRequestID = UUID(); let token = searchRequestID
        loading = true; failure = nil
        defer { if searchRequestID == token { loading = false } }
        do {
            let page: CatalogPage
            if selectedSource == "saavn" {
                guard preferences.values.saavnEnabled else { return }
                let tracks = try await SaavnService.shared.search(term)
                page = CatalogPage(items: tracks.map { CatalogItem(id: $0.id.uuidString, title: $0.title, subtitle: $0.artist, artwork: $0.artworkURL, track: $0) }, continuation: nil)
            } else { page = try await MusicCatalog.shared.search(term, continuation: more ? continuation : nil) }
            try Task.checkCancellation()
            guard searchRequestID == token, source == selectedSource, query.trimmingCharacters(in: .whitespacesAndNewlines) == term, online else { return }
            if more { let seen = Set(items.map(\.id)); items += page.items.filter { !seen.contains($0.id) } } else { items = page.items }
            continuation = page.continuation
        } catch { if !Task.isCancelled && searchRequestID == token && source == selectedSource && term == query.trimmingCharacters(in: .whitespacesAndNewlines) { failure = error.localizedDescription } }
    }
}

// Deterministic LOCAL test route. Live catalog coverage stays in its own suite.
private struct LocalExploreView: View {
    @EnvironmentObject var library: LibraryStore
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                AndroidPageHeading(title: "Explore")
                OnlineTrackShelf(title: "On this device", subtitle: "Your local music", tracks: library.tracks)
                VStack(alignment: .leading, spacing: 10) {
                    AndroidSectionHeading(title: "Artists")
                    ForEach(Array(Set(library.tracks.map(\.artist))).sorted(), id: \.self) { artist in
                        RouteLink { TrackCollection(title: artist, tracks: library.tracks.filter { $0.artist == artist }) } label: {
                            Label(artist, systemImage: "person.crop.circle").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 16)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    AndroidSectionHeading(title: "Albums")
                    ForEach(Array(Set(library.tracks.map(\.album))).sorted(), id: \.self) { album in
                        RouteLink { TrackCollection(title: album, tracks: library.tracks.filter { $0.album == album }) } label: {
                            Label(album, systemImage: "square.stack").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 16)
                        }
                    }
                }
            }.padding(.bottom, 24)
        }.background(Color(uiColor: .systemBackground)).navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}
