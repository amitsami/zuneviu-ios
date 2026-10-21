import SwiftUI
import UIKit

struct Brand: View {
    var body: some View {
        (Text("Z").foregroundColor(AndroidDesign.accent) + Text("unéviu").foregroundColor(.primary))
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
    @EnvironmentObject private var downloads: DownloadManager
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
            if library.track(track.id)?.isLocal == true { Image(systemName: "arrow.down.circle.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Available offline") }
            if library.snapshot.favorites.contains(track.id) { Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink) }
            Menu {
                IconButton("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { playback.enqueue(track, next: true) }
                IconButton("Add to queue", systemImage: "text.badge.plus") { playback.enqueue(track) }
                IconButton(library.snapshot.favorites.contains(track.id) ? "Unlike" : "Like", systemImage: "heart") { library.remember(track); library.toggleFavorite(track.id) }
                if !track.isLocal, track.hasOnlineSource { IconButton("Download", systemImage: "arrow.down.circle") { downloads.enqueue(track) } }
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

struct TrackSortPicker: View {
    @Binding var selection: String
    var body: some View {
        Picker("Sort", selection: $selection) {
            Text("Newest first").tag("newest")
            Text("Oldest first").tag("oldest")
            Text("Title A–Z").tag("title")
            Text("Title Z–A").tag("titleDescending")
        }
    }
}

// Direct visual tokens from Android sharedUi Common.kt and ui/theme/Theme.kt.
private struct AndroidPageWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 390 }
extension EnvironmentValues {
    var androidPageWidth: CGFloat {
        get { self[AndroidPageWidthKey.self] }
        set { self[AndroidPageWidthKey.self] = newValue }
    }
}
enum AndroidDesign {
    static let gutter: CGFloat = 16
    static let cardWidth: CGFloat = 150
    static let accent = Color(red: 250 / 255, green: 45 / 255, blue: 72 / 255)
    static func heroWidth(_ width: CGFloat) -> CGFloat { min(width * 0.70, 320) }
}
struct AndroidPageHeading: View {
    let title: String
    var branded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if branded { Brand() }
            Text(title).font(.system(size: 34, weight: .heavy)).tracking(-0.8)
                .accessibilityAddTraits(.isHeader)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 8)
    }
}
struct AndroidSectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 22, weight: .bold)).tracking(-0.4)
                .accessibilityAddTraits(.isHeader)
            if let subtitle, !subtitle.isEmpty { Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
    }
}
struct AndroidSettingsSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(
            LinearGradient(colors: scheme == .dark ? [Color(white: 0.13), Color(white: 0.065)] : [Color(white: 0.98), Color(white: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28)
        ).overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.primary.opacity(0.20), lineWidth: 0.65))
    }
}
struct AndroidCanvas: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16, *) { content.scrollContentBackground(.hidden).background(Color(uiColor: .systemBackground)) }
        else { content.background(Color(uiColor: .systemBackground)) }
    }
}
// Native UISearchTextField retains accessible search semantics;
// its position is controlled by the Android page, not a large iOS navigation bar.
struct AndroidSettingsSearch: UIViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField(frame: .zero)
        field.placeholder = "Search settings"; field.accessibilityLabel = "Search settings"
        field.font = .systemFont(ofSize: 16); field.returnKeyType = .search
        field.autocorrectionType = .no; field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text { field.text = text }
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        @objc func changed(_ field: UITextField) { text.wrappedValue = field.text ?? "" }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
    }
}
