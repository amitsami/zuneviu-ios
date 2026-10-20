import SwiftUI

struct HomeView: View {
    let importAction: () -> Void
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { LocalHomeView(importAction: importAction) }
        else { CatalogHomeView(explore: false) }
    }
}
struct ExploreView: View {
    var body: some View { CatalogHomeView(explore: true) }
}
struct CatalogHomeView: View {
    let explore: Bool
    @EnvironmentObject var library: LibraryStore
    @State private var shelves: [CatalogShelf] = []
    @State private var loading = false
    @State private var failure: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !explore {
                    if !library.recent.isEmpty { OnlineTrackShelf(title: "Listen again", subtitle: "From your listening", tracks: library.recent) }
                    if !library.favorites.isEmpty { OnlineTrackShelf(title: "Made for you", subtitle: "Songs you love", tracks: library.favorites) }
                }
                if loading && shelves.isEmpty { ProgressView("Loading music…").frame(maxWidth: .infinity).padding(50) }
                if let failure { ServiceFailure(message: failure) { Task { await refresh() } } }
                ForEach(shelves) { shelf in CatalogShelfView(shelf: shelf) }
                if !loading && shelves.isEmpty && failure == nil {
                    ContentUnavailableView("No music returned", systemImage: "music.note", description: Text("Pull down to retry or search for a song."))
                }
            }.padding(.vertical, 18)
        }
        .navigationTitle(explore ? "Explore" : "Listen Now")
        .refreshable { await refresh() }
        .task { if shelves.isEmpty { await refresh() } }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(shelf.title.isEmpty ? "Discover" : shelf.title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(shelf.items) { item in CatalogCard(item: item, context: shelf.items.compactMap(\.track)) }
                }.padding(.horizontal)
            }
        }
    }
}
struct OnlineTrackShelf: View {
    var title: String
    var subtitle: String
    var tracks: [Track]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.title2.bold()); Text(subtitle).foregroundStyle(.secondary).font(.subheadline) }.padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(tracks.prefix(15)) { track in
                        CatalogCard(item: CatalogItem(id: track.id.uuidString, title: track.title, subtitle: track.artist, artwork: track.artworkURL, track: track), context: tracks)
                    }
                }.padding(.horizontal)
            }
        }
    }
}
struct CatalogCard: View {
    let item: CatalogItem
    let context: [Track]
    @EnvironmentObject var playback: PlaybackStore
    var body: some View {
        Group {
            if let track = item.track { Button { playback.play(track, in: context) } label: { card }.buttonStyle(.plain).accessibilityLabel("Play \(track.title) by \(track.artist)") }
            else if let id = item.browseID { NavigationLink { CatalogBrowseView(id: id, title: item.title, params: item.params) } label: { card }.buttonStyle(.plain) }
        }
    }
    private var card: some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if let track = item.track { Artwork(track: track) }
                else { AsyncImage(url: item.artwork.flatMap(URL.init(string:))) { image in image.resizable().scaledToFill() } placeholder: { Color(white: 0.12).overlay(Image(systemName: "music.note.list")) } }
            }.frame(width: 158, height: 158).clipped().clipShape(RoundedRectangle(cornerRadius: 15))
            Text(item.title).font(.headline).lineLimit(1)
            Text(item.track?.artist ?? item.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }.frame(width: 158, alignment: .leading)
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
            if !tracks.isEmpty { Button("Play all", systemImage: "play.fill") { playback.play(tracks[0], in: tracks) } }
            if loading && items.isEmpty { ProgressView("Loading…") }
            if let failure { ServiceFailure(message: failure) { Task { await load(more: false) } } }
            ForEach(items) { item in
                if let track = item.track { TrackRow(track: track, context: tracks) }
                else if let nextID = item.browseID, nextID != id {
                    NavigationLink { CatalogBrowseView(id: nextID, title: item.title, params: item.params) } label: { Label(item.title, systemImage: "square.stack") }
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
                if loading { ProgressView("Searching music…") }
                if let failure { ServiceFailure(message: failure) { Task { await search(more: false) } } }
                ForEach(items) { item in
                    if let track = item.track { TrackRow(track: track, context: items.compactMap(\.track)) }
                }
                if continuation != nil { Button("Load more results") { Task { await search(more: true) } }.disabled(loading) }
                if !loading && items.isEmpty && failure == nil {
                    ContentUnavailableView(query.isEmpty ? "Find your next favorite" : "No results", systemImage: "magnifyingglass", description: Text(query.isEmpty ? "Search the online music catalog." : "Try another song or artist."))
                }
            } else {
                ForEach(localResults) { TrackRow(track: $0, context: localResults) }
                if localResults.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }.listStyle(.plain).navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, artists, albums")
            .task(id: query + String(online)) {
                guard online else { return }
                items = []; continuation = nil; failure = nil
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                do { try await Task.sleep(for: .milliseconds(450)); try Task.checkCancellation(); await search(more: false) } catch { }
            }
    }
    @MainActor private func search(more: Bool) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        loading = true; failure = nil
        defer { loading = false }
        do {
            let page = try await MusicCatalog.shared.search(term, continuation: more ? continuation : nil)
            try Task.checkCancellation()
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == term, online else { return }
            if more { let seen = Set(items.map(\.id)); items += page.items.filter { !seen.contains($0.id) } } else { items = page.items }
            continuation = page.continuation
        } catch { if !Task.isCancelled && term == query.trimmingCharacters(in: .whitespacesAndNewlines) { failure = error.localizedDescription } }
    }
}
