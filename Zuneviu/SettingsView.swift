import SwiftUI

struct SettingsView: View {
    var closeAction: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private let groups: [[(String, String)]] = [
        [("Account & integrations", "person.fill")],
        [("Audio quality", "headphones"), ("Video quality", "video.fill"), ("Playback", "play.fill"), ("Appearance", "circle.lefthalf.filled")],
        [("Downloads", "arrow.down"), ("Personalized discovery", "sparkles"), ("Performance", "bolt.fill"), ("Lyrics", "text.bubble")],
        [("Sources", "antenna.radiowaves.left.and.right"), ("About & licenses", "info.circle")]
    ]
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                AndroidPageHeading(title: "Settings", branded: true)
                AndroidSettingsSearch(text: $search).frame(height: 50).padding(.horizontal, 16)
                ForEach(groups.indices, id: \.self) { index in
                    let filtered = groups[index].filter { search.isEmpty || $0.0.localizedCaseInsensitiveContains(search) }
                    if !filtered.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filtered.indices, id: \.self) { row in
                                let item = filtered[row]
                                RouteLink { SettingDetail(title: item.0) } label: {
                                    HStack(spacing: 18) {
                                        Image(systemName: item.1).font(.system(size: 20, weight: .semibold)).frame(width: 26)
                                        VStack(alignment: .leading, spacing: 3) {
                                            if item.0 == "Account & integrations" { Brand() }
                                            Text(item.0).font(.system(size: 16))
                                            if item.0 == "Account & integrations" { Text("Not signed in").font(.system(size: 14)).foregroundStyle(.secondary) }
                                        }
                                        Spacer(minLength: 6)
                                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                                    }.foregroundStyle(.primary).padding(.horizontal, 20).padding(.vertical, 20)
                                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(item.0)
                                if row < filtered.count - 1 { Divider().padding(.leading, 64).opacity(0.35) }
                            }
                        }.modifier(AndroidSettingsSurface()).padding(.horizontal, 16)
                    }
                }
                Text("Native iOS development port · Not full Android parity").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 20)
            }.padding(.bottom, 24)
        }.background(Color(uiColor: .systemBackground)).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { if let closeAction { closeAction() } else { dismiss() } } label: {
                        Image(systemName: "arrow.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("Close settings").tint(.primary)
                }
            }
    }
}
struct SettingDetail: View {
    let title: String
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    @EnvironmentObject var preferences: PreferenceStore
    @EnvironmentObject var discovery: DiscoveryStore
    @EnvironmentObject var downloads: DownloadManager
    @State private var cacheMessage: String?
    @State private var confirmReset = false
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("playbackRate") private var rate: Double = 1
    @AppStorage("lyricOffset") private var lyricOffset: Double = 0
    var body: some View {
        Form {
            switch title {
            case "Playback":
                Section {
                    Toggle("Autoplay related songs", isOn: $preferences.values.autoplay)
                    Toggle("Shuffle", isOn: $playback.shuffle)
                    Picker("Repeat", selection: $playback.repeatMode) {
                        Text("Off").tag(RepeatMode.off); Text("All").tag(RepeatMode.all); Text("One").tag(RepeatMode.one)
                    }
                }
                Section("Speed") {
                    Picker("Playback speed", selection: $rate) {
                        Text("0.75×").tag(0.75); Text("Normal").tag(1.0); Text("1.25×").tag(1.25); Text("1.5×").tag(1.5); Text("2×").tag(2.0)
                    }.onChange(of: rate) { _ in if playback.isPlaying { playback.resume() } }
                }
                Section("Sleep timer") {
                    ForEach([15, 30, 45, 60], id: \.self) { value in Button("\(value) minutes") { playback.setSleep(minutes: value) } }
                    Button("Cancel timer") { playback.setSleep(minutes: nil) }
                    if let deadline = playback.sleepDeadline { Text("Stops \(deadline, style: .time)") }
                }
                Section { Text("Shuffle and repeat are available in Now Playing. Gapless playback, crossfade and Android's equalizer have not been ported.") }
            case "Appearance":
                Section("Theme") {
                    Picker("Theme", selection: $theme) { Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }
                }
                Section("Artwork & controls") {
                    Toggle("Full-bleed artwork", isOn: $preferences.values.fullBleedArtwork)
                    Toggle("Hide volume slider", isOn: $preferences.values.hideVolumeBar)
                    Toggle("Hide song status", isOn: $preferences.values.hideSongStatus)
                    Toggle("Glass styling", isOn: $preferences.values.liquidGlass)
                }
                Section { Text("Native Liquid Glass is used on iOS 26. Earlier versions use a translucent material fallback. System Reduce Transparency always takes priority.").font(.footnote) }
            case "Lyrics":
                Section {
                    Toggle("Synchronized lyrics", isOn: $preferences.values.syncedLyrics)
                    Toggle("Blur inactive lines", isOn: $preferences.values.lyricsBlur)
                }
                Section("Timing") {
                    Text(String(format: "Offset: %+.1f seconds", lyricOffset)).monospacedDigit()
                    Slider(value: $lyricOffset, in: -10...10, step: 0.1).accessibilityLabel("Lyric timing offset")
                    Button("Reset offset") { lyricOffset = 0 }
                }
                Section { Text("Import UTF-8 .lrc or .txt lyrics from the Now Playing ••• menu. Synced lines can be tapped to seek. Online plain lyrics are requested from YouTube Music when available. Imported synced lyrics remain supported.") }
            case "Audio quality":
                Section { Text("Imported audio plays from the original file using AVPlayer. Actual output depends on the file, route and iOS. No upsampling or lossless guarantee is claimed.") }
                Section("Streaming quality") {
                    qualityPicker("Wi-Fi", selection: $preferences.values.audioQualityWifi)
                    qualityPicker("Cellular", selection: $preferences.values.audioQualityCellular)
                    Toggle("Allow cellular streaming", isOn: $preferences.values.cellularStreamingAllowed)
                }
                Section { Text("These are bitrate ceilings, not quality upgrades. Playback fails rather than silently exceeding a chosen ceiling when the source has no compatible rendition. Best available does not imply lossless.").font(.footnote) }
            case "Sources":
                Section("YouTube Music") {
                    Label("Guest catalog & search", systemImage: "magnifyingglass")
                    Text("Uses the Android app’s catalog protocol and an on-device iOS extractor. A visible song is not proof that its audio is available. Some requests currently require provider verification; playback and downloads can fail.")
                }
                Section("JioSaavn · optional") {
                    Toggle("Enable JioSaavn catalog", isOn: $preferences.values.saavnEnabled).accessibilityIdentifier("sources.saavn")
                    Text("Off by default, like Android. Enables a separate catalog selector in online Search. Songs keep their source identity; YouTube songs are never silently replaced by covers or other recordings. Availability varies by region and provider. Requests go directly to JioSaavn and its audio CDN.")
                }
                Section("Private Android sources") {
                    Text("Private addon/module configuration is not in the repository and is not executed by this app.")
                    Text("No location-spoofing headers, shared account cookies or third-party extraction proxies are used.")
                }
                Section("Offline source") { Text("Import your own compatible audio using Library → Import music. These files do not depend on an online provider.") }
            case "Video quality":
                Text("Inline music video and video quality settings have not been ported to iOS.")
            case "Account & integrations":
                Label("Not connected", systemImage: "person.crop.circle.badge.questionmark")
                Text("Google, YouTube Music and Spotify authentication/sync are not implemented in this build. Android credentials are not reused or requested.")
            case "Downloads":
                Section {
                    qualityPicker("Download quality", selection: $preferences.values.downloadQuality)
                    Toggle("Wi-Fi only downloads", isOn: $preferences.values.wifiOnlyDownloads)
                    RouteLink("Manage downloads") { DownloadsView() }
                    HStack { Text("Downloaded songs"); Spacer(); Text("\(library.downloads.count)") }
                    HStack { Text("All on-device songs"); Spacer(); Text("\(library.onDevice.count)") }
                }
                Section { Text("Queue supports progress, cancel, retry and complete-file validation. A working source must supply a complete playable file. Downloads interrupted by closing the app must be retried; background completion and HLS/DASH offline packaging are not implemented. Deleting the app deletes its offline library.").font(.footnote) }
            case "Personalized discovery":
                Section {
                    Toggle("Local recommendations", isOn: $preferences.values.localRecommendations)
                    Toggle("Avoid songs in listening history", isOn: $preferences.values.dontRepeatSuggestions)
                    Toggle("Record listening history", isOn: $preferences.values.recordListeningHistory)
                    HStack { Text("Qualified discovery seeds"); Spacer(); Text("\(discovery.seeds.count) / 8") }
                }
                Section { Text("Like the Android local discovery policy, a song qualifies after 20 seconds of actual listening. Up to eight device-local seeds request related songs, interleaved and deduplicated. For JioSaavn seeds, related candidates come from artist search; this is an iOS extension of the local policy, not Android’s YouTube radio. This is not Google-account personalization. A working online source is required for fresh suggestions.").font(.footnote) }
                Section {
                    Button("Reset local discovery & history", role: .destructive) { confirmReset = true }
                    Text("Favorites, playlists, imports and downloads are kept.").font(.footnote)
                }
            case "Performance":
                Section("Accessibility & motion") {
                    Toggle("Reduce animations", isOn: $preferences.values.reduceAnimation)
                    Toggle("Reduce dynamic blur", isOn: $preferences.values.reduceDynamicBlur)
                    Text("System accessibility settings take priority. Reducing blur uses solid surfaces and disables the blurred player backdrop.").font(.footnote)
                }
                Section("Artwork memory cache") {
                    Picker("Memory budget", selection: $preferences.values.imageCacheBudgetMiB) {
                        ForEach([16, 32, 48, 64], id: \.self) { Text("\($0) MiB").tag($0) }
                    }
                    Button("Clear artwork cache") {
                        Task { await ArtworkLoader.shared.clear(); cacheMessage = "Artwork cache cleared. Music and downloads were kept." }
                    }
                    if let cacheMessage { Text(cacheMessage).font(.footnote).accessibilityIdentifier("cache.feedback") }
                    Text("Artwork is downsampled off the main thread. Playback-clock updates are isolated from library/navigation updates. No measured FPS or battery-life improvement is claimed.").font(.footnote)
                }
            default:
                Section {
                    Brand(); Text("iOS \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development") · Development port")
                    Text("Original Android app: Amit Hasan Sami. This SwiftUI port includes the original WEB_REMIX catalog protocol and a native on-device extractor. It is still not a feature-complete Android replacement.")
                    Link("Original repository", destination: URL(string: "https://github.com/amitsami/zunevio-releases")!)
                }
                Section("Source, privacy & notices") {
                    Text("No analytics or sign-in. Catalog queries, playback requests and artwork requests contact YouTube/Google directly, or JioSaavn and its CDN when that optional source is enabled. Optional remote extraction proxies are disabled. Imported music, favorites, playlists and history stay in this app. AirPlay and system sharing act only when selected. Files and iCloud providers may use their own network services.")
                    RouteLink("Open-source notices") { ScrollView { Text(legalText).font(.footnote.monospaced()).textSelection(.enabled).padding() }.navigationTitle("Notices") }
                    Text("See LICENSE and UPSTREAM-NOTICE.md in the source archive. Required upstream attribution is retained. No warranty.")
                }
            }
        }.modifier(AndroidCanvas()).tint(.primary).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset local discovery and history?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { discovery.clear(); library.clearHistory() }
        } message: { Text("This cannot be undone. Your audio, favorites and playlists will not be removed.") }
    }
    private func qualityPicker(_ title: String, selection: Binding<AudioQuality>) -> some View {
        Picker(title, selection: selection) { ForEach(AudioQuality.allCases) { Text($0.title).tag($0) } }
    }
    private var legalText: String {
        ["LICENSE", "UPSTREAM-NOTICE", "ASSET-CREDITS"].compactMap { name -> String? in
            let ext = name == "LICENSE" ? "txt" : "md"
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n————————\n\n")
    }
}
