import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var library: LibraryStore
    @State private var search = ""
    private let items: [(String, String)] = [
        ("Account & integrations", "person.fill"), ("Audio quality", "headphones"), ("Video quality", "video.fill"),
        ("Playback", "play.fill"), ("Appearance", "circle.lefthalf.filled"), ("Downloads", "arrow.down"),
        ("Personalized discovery", "sparkles"), ("Performance", "bolt.fill"), ("Lyrics", "text.bubble"), ("About & licenses", "info.circle")]
    var body: some View {
        List {
            Section { Brand() }
            ForEach(items.filter { search.isEmpty || $0.0.localizedCaseInsensitiveContains(search) }, id: \.0) { item in
                NavigationLink { SettingDetail(title: item.0) } label: { Label(item.0, systemImage: item.1).padding(.vertical, 9) }
            }
            Section { Text("Native iOS development port · Not full Android parity").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Settings").searchable(text: $search, prompt: "Search settings")
    }
}
struct SettingDetail: View {
    let title: String
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("playbackRate") private var rate: Double = 1
    @AppStorage("lyricOffset") private var lyricOffset: Double = 0
    var body: some View {
        Form {
            switch title {
            case "Playback":
                Section("Speed") {
                    Picker("Playback speed", selection: $rate) {
                        Text("0.75×").tag(0.75); Text("Normal").tag(1.0); Text("1.25×").tag(1.25); Text("1.5×").tag(1.5); Text("2×").tag(2.0)
                    }.onChange(of: rate) { _, _ in if playback.isPlaying { playback.resume() } }
                }
                Section("Sleep timer") {
                    ForEach([15, 30, 45, 60], id: \.self) { value in Button("\(value) minutes") { playback.setSleep(minutes: value) } }
                    Button("Cancel timer") { playback.setSleep(minutes: nil) }
                    if let deadline = playback.sleepDeadline { Text("Stops \(deadline, style: .time)") }
                }
                Section { Text("Shuffle and repeat are available in Now Playing. Gapless playback, crossfade and Android's equalizer have not been ported.") }
            case "Appearance":
                Picker("Theme", selection: $theme) { Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }
            case "Lyrics":
                Section("Timing") {
                    Text(String(format: "Offset: %+.1f seconds", lyricOffset)).monospacedDigit()
                    Slider(value: $lyricOffset, in: -10...10, step: 0.1).accessibilityLabel("Lyric timing offset")
                    Button("Reset offset") { lyricOffset = 0 }
                }
                Section { Text("Import UTF-8 .lrc or .txt lyrics from the Now Playing ••• menu. Synced lines can be tapped to seek. Online plain lyrics are requested from YouTube Music when available. Imported synced lyrics remain supported.") }
            case "Audio quality":
                Section { Text("Imported audio plays from the original file using AVPlayer. Actual output depends on the file, route and iOS. No upsampling or lossless guarantee is claimed.") }
                Section("Streaming quality") { Text("Streaming chooses the highest-bitrate natively playable audio candidate returned by the extractor. Separate Wi-Fi/cellular preferences are not yet implemented. Availability and output quality depend on the provider and iOS route.") }
            case "Video quality":
                Text("Inline music video and video quality settings have not been ported to iOS.")
            case "Account & integrations":
                Label("Not connected", systemImage: "person.crop.circle.badge.questionmark")
                Text("Google, YouTube Music and Spotify authentication/sync are not implemented in this build. Android credentials are not reused or requested.")
            case "Downloads":
                LabeledContent("On-device songs", value: "\(library.tracks.count)")
                Text("Imported music is copied into the app's Application Support folder and plays offline. Provider downloads are not available. Removing a song removes only the app's copy. Deleting the app removes its library.")
            case "Personalized discovery":
                Text("Listen Now shows guest YouTube Music shelves plus your locally recorded history and favorites. Account-personalized recommendations require sign-in, which is not implemented yet.")
                Text("Listening history is stored only in this app's sandbox.")
            case "Performance":
                Text("Audio playback uses iOS AVPlayer. Artwork is loaded from imported files or the catalog artwork URL. No Android cache, decoder, AI stem separation or smart-transition engine is included.")
            default:
                Section {
                    Brand(); Text("iOS 0.2.0 · Development port")
                    Text("Original Android app: Amit Hasan Sami. This SwiftUI port includes the original WEB_REMIX catalog protocol and a native on-device extractor. It is still not a feature-complete Android replacement.")
                    Link("Original repository", destination: URL(string: "https://github.com/amitsami/zunevio-releases")!)
                }
                Section("Source, privacy & notices") {
                    Text("No analytics or sign-in. Catalog queries, playback requests and artwork requests contact YouTube/Google directly. Optional remote extraction proxies are disabled. Imported music, favorites, playlists and history stay in this app. AirPlay and system sharing act only when selected. Files and iCloud providers may use their own network services.")
                    NavigationLink("Open-source notices") { ScrollView { Text(legalText).font(.footnote.monospaced()).textSelection(.enabled).padding() }.navigationTitle("Notices") }
                    Text("See LICENSE and UPSTREAM-NOTICE.md in the source archive. Required upstream attribution is retained. No warranty.")
                }
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
    private var legalText: String {
        ["LICENSE", "UPSTREAM-NOTICE", "ASSET-CREDITS"].compactMap { name -> String? in
            let ext = name == "LICENSE" ? "txt" : "md"
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n————————\n\n")
    }
}
