import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    let importAction: () -> Void
    @State private var newPlaylist = false
    @State private var playlistName = ""
    @State private var pendingRemoval: Track?
    @AppStorage("librarySort") private var sort = "newest"
    private var sorted: [Track] {
        TrackOrdering.sorted(library.onDevice, by: sort)
    }
    @Environment(\.androidPageWidth) private var pageWidth
    private func libraryRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 28)
            Text(title).font(.system(size: 16))
            Spacer(); Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        }.frame(minHeight: 58).contentShape(Rectangle())
    }
    private func collectionTile(_ title: String, subtitle: String, track: Track?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let track { Artwork(track: track, radius: 12) }
                else { RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.08)).overlay(Image(systemName: icon).font(.system(size: 38)).foregroundStyle(.secondary)) }
            }.frame(width: 150, height: 150)
            Text(title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(2)
        }.frame(width: 150, alignment: .leading)
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                AndroidPageHeading(title: "Library")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("YOUR LISTENING EXPERIENCE").font(.system(size: 11, weight: .semibold)).tracking(1.2)
                                Spacer(); Image(systemName: "music.note")
                            }.foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(library.snapshot.listenedSeconds / 60))").font(.system(size: 30, weight: .heavy))
                            Text("MINUTES LISTENED").font(.system(size: 11, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                            Spacer()
                            Text("Zunéviu LISTENER").font(.system(size: 14, weight: .semibold, design: .monospaced))
                        }.foregroundStyle(.white).padding(20).frame(width: min(pageWidth * 0.82, 340), height: 190)
                            .background(LinearGradient(colors: [Color(red: 0.20, green: 0.13, blue: 0.15), Color(red: 0.07, green: 0.07, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
                    }.padding(.horizontal, 16)
                }
                VStack(spacing: 0) {
                    RouteLink { DownloadsView() } label: { libraryRow("Downloads · \(library.downloads.count)", icon: "arrow.down.to.line") }
                    Divider().padding(.leading, 52)
                    RouteLink { TrackCollection(title: "Local Music", tracks: sorted) } label: { libraryRow("Local Music", icon: "folder.fill") }
                }.padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 14) {
                    AndroidSectionHeading(title: "On Device")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            RouteLink { FavoritesView() } label: {
                                collectionTile("Liked songs", subtitle: "\(library.favorites.count) songs · On this device", track: library.favorites.first, icon: "heart.fill")
                            }.accessibilityLabel("Liked songs · \(library.favorites.count)")
                            RouteLink { TrackCollection(title: "Recently played", tracks: library.recent) } label: {
                                collectionTile("Recently played", subtitle: "Your listening history", track: library.recent.first, icon: "clock.arrow.circlepath")
                            }
                        }.padding(.horizontal, 16)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Playlists").font(.system(size: 22, weight: .bold)).tracking(-0.4)
                        Spacer()
                        Button { newPlaylist = true } label: { Label("New playlist", systemImage: "plus").font(.system(size: 14, weight: .semibold)).frame(minHeight: 44) }
                    }.padding(.horizontal, 16)
                    if !library.snapshot.playlists.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(library.snapshot.playlists) { playlist in
                                    RouteLink { PlaylistView(id: playlist.id) } label: {
                                        collectionTile(playlist.name, subtitle: "\(playlist.trackIDs.count) songs", track: playlist.trackIDs.first.flatMap { library.track($0) }, icon: "music.note.list")
                                    }.contextMenu { Button("Delete playlist", role: .destructive) { library.deletePlaylist(playlist.id) } }
                                }
                            }.padding(.horizontal, 16)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Local Music").font(.system(size: 22, weight: .bold))
                        Spacer()
                        Menu { TrackSortPicker(selection: $sort) } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44) }.accessibilityLabel("Sort library")
                    }
                    if library.onDevice.isEmpty { EmptyLibrary(importAction: importAction) }
                    ForEach(sorted) { track in
                        TrackRow(track: track, context: sorted).contextMenu { Button("Remove imported song", role: .destructive) { pendingRemoval = track } }
                    }
                    IconButton("Import from Files", systemImage: "square.and.arrow.down") { importAction() }.frame(minHeight: 44).disabled(library.isImporting)
                    RouteLink { TrackCollection(title: "Saved online songs", tracks: library.tracks.filter { !$0.isLocal }) } label: { libraryRow("Saved online songs", icon: "cloud") }
                }.padding(.horizontal, 16)
            }.padding(.bottom, 24)
        }.background(Color(uiColor: .systemBackground)).tint(.primary).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .onAppear { if sort == "added" { sort = "newest" } }
            .sheet(isPresented: $newPlaylist) {
                CompatibleNavigation {
                    Form { TextField("Playlist name", text: $playlistName).accessibilityIdentifier("playlist.name") }
                        .navigationTitle("New playlist")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { newPlaylist = false; playlistName = "" } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Create") { library.createPlaylist(playlistName); playlistName = ""; newPlaylist = false }
                                    .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                }
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
