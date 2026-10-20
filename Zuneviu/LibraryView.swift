import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    let importAction: () -> Void
    @State private var newPlaylist = false
    @State private var playlistName = ""
    @State private var pendingRemoval: Track?
    @AppStorage("librarySort") private var sort = "added"
    private var sorted: [Track] {
        sort == "title" ? library.tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } : Array(library.tracks.reversed())
    }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 18) {
                    Text("YOUR LISTENING EXPERIENCE").font(.caption.weight(.semibold)).tracking(1.2)
                    Text("\(Int(library.snapshot.listenedSeconds / 60))").font(.system(size: 38, weight: .bold))
                    Text("MINUTES LISTENED").font(.caption).tracking(1.4)
                    Text("Zunéviu LISTENER").font(.headline)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.pink.opacity(0.18), .gray.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                Button("Import from Files", systemImage: "square.and.arrow.down") { importAction() }.disabled(library.isImporting)
                NavigationLink { FavoritesView() } label: { Label("Liked songs · \(library.favorites.count)", systemImage: "heart.fill").foregroundStyle(.pink) }
                NavigationLink { TrackCollection(title: "Recently played", tracks: library.recent) } label: { Label("Recently played", systemImage: "clock.arrow.circlepath") }
            }
            Section {
                ForEach(library.snapshot.playlists) { playlist in
                    NavigationLink { PlaylistView(id: playlist.id) } label: {
                        HStack { Label(playlist.name, systemImage: "music.note.list"); Spacer(); Text("\(playlist.trackIDs.count)").foregroundStyle(.secondary) }
                    }.swipeActions { Button("Delete", role: .destructive) { library.deletePlaylist(playlist.id) } }
                }
                Button("New playlist", systemImage: "plus") { newPlaylist = true }
            } header: { Text("Playlists") }
            Section {
                if library.tracks.isEmpty { EmptyLibrary(importAction: importAction).listRowBackground(Color.clear) }
                ForEach(sorted) { track in
                    TrackRow(track: track, context: sorted).swipeActions {
                        Button("Remove", role: .destructive) { pendingRemoval = track }
                    }
                }
            } header: {
                HStack {
                    Text("On Device")
                    Spacer()
                    Menu {
                        Picker("Sort", selection: $sort) { Text("Recently added").tag("added"); Text("Title").tag("title") }
                    } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 32) }.accessibilityLabel("Sort library")
                }
            }
        }.listStyle(.insetGrouped).navigationTitle("Library")
            .alert("New playlist", isPresented: $newPlaylist) {
                TextField("Playlist name", text: $playlistName)
                Button("Create") { library.createPlaylist(playlistName); playlistName = "" }
                Button("Cancel", role: .cancel) { playlistName = "" }
            }
            .confirmationDialog("Remove this imported song?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
                Button("Remove from this app", role: .destructive) {
                    if let track = pendingRemoval {
                        playback.removeFromQueue(track.id)
                        library.remove(track.id)
                    }
                    pendingRemoval = nil
                }
            } message: { Text("The original file in Files is not deleted.") }
    }
}
struct FavoritesView: View {
    @EnvironmentObject var library: LibraryStore
    var body: some View { TrackCollection(title: "Liked songs", tracks: library.favorites) }
}
struct PlaylistView: View {
    @EnvironmentObject var library: LibraryStore
    let id: UUID
    private var playlist: Playlist? { library.snapshot.playlists.first { $0.id == id } }
    var body: some View {
        TrackCollection(title: playlist?.name ?? "Playlist", tracks: (playlist?.trackIDs ?? []).compactMap { library.track($0) })
            .overlay {
                if playlist?.trackIDs.isEmpty == true { Text("Add songs using a song's ••• menu.").foregroundStyle(.secondary).padding() }
            }
    }
}
