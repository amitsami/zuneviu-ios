import SwiftUI
import UIKit

struct Brand: View {
    var body: some View {
        (Text("Z").foregroundColor(.pink) + Text("unéviu").foregroundColor(.primary))
            .font(.system(size: 21, weight: .semibold))
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Zunéviu").accessibilityIdentifier("brand.name")
    }
}
struct Artwork: View {
    @EnvironmentObject var library: LibraryStore
    var track: Track?
    var radius: CGFloat = 16
    private var source: URL? {
        if let file = track?.artworkFile { return library.file(file) }
        return track?.artworkURL.flatMap(URL.init(string:))
    }
    var body: some View {
        CachedArtwork(url: source)
            .clipped().clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct TrackRow: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    let track: Track
    let context: [Track]
    var body: some View {
        HStack(spacing: 12) {
            Button { playback.play(track, in: context) } label: {
                HStack(spacing: 12) {
                    Artwork(track: track, radius: 9).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).font(.body.weight(.semibold)).lineLimit(1)
                        Text(track.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if library.snapshot.favorites.contains(track.id) { Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink) }
            Menu {
                IconButton("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { playback.enqueue(track, next: true) }
                IconButton("Add to queue", systemImage: "text.badge.plus") { playback.enqueue(track) }
                IconButton(library.snapshot.favorites.contains(track.id) ? "Unlike" : "Like", systemImage: "heart") { library.remember(track); library.toggleFavorite(track.id) }
                if track.videoID != nil { IconButton("Start radio", systemImage: "dot.radiowaves.left.and.right") { playback.startRadio(track) } }
                if let id = track.artistBrowseID { RouteLink("Open artist") { CatalogBrowseView(id: id, title: track.artist) } }
                if let id = track.albumBrowseID { RouteLink("Open album") { CatalogBrowseView(id: id, title: track.album) } }
                if !library.snapshot.playlists.isEmpty {
                    Menu("Add to playlist") {
                        ForEach(library.snapshot.playlists) { list in Button(list.name) { library.remember(track); library.add(track.id, to: list.id) } }
                    }
                }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle()) }
            .accessibilityLabel("Options for \(track.title)")
        }.padding(.vertical, 5)
    }
}
struct TrackCollection: View {
    let title: String
    let tracks: [Track]
    @EnvironmentObject var playback: PlaybackStore
    var body: some View {
        List {
            if !tracks.isEmpty {
                IconButton("Play all", systemImage: "play.fill") { playback.play(tracks[0], in: tracks) }
                ForEach(tracks) { TrackRow(track: $0, context: tracks) }
            } else { EmptyStateView("No music yet", systemImage: "music.note", description: Text("Import audio from Files to fill your library.")) }
        }.listStyle(.plain).navigationTitle(title).navigationBarTitleDisplayMode(.large)
    }
}
struct EmptyLibrary: View {
    var importAction: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image("MusicMark").resizable().scaledToFit().frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 20))
            Text("Your music. Your flow.").font(.title2.bold())
            Text("Bring your own music from Files. Your library stays on your iPhone.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            IconButton("Import music", systemImage: "plus") { importAction() }.buttonStyle(.borderedProminent)
            Text("MP3 · M4A · WAV · FLAC, where supported by iOS. DRM-protected files are not supported.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(28).frame(maxWidth: .infinity)
    }
}
