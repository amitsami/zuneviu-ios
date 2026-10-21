import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer
import AVKit

struct NowPlayingView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var preferences: PreferenceStore
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    @EnvironmentObject var clock: PlaybackClock
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var showingTrackOptions = false
    @State private var deferredTrackAction: (() -> Void)?
    @State private var showingQueue = false
    @State private var showingLyrics = false
    @State private var importingLyrics = false
    @State private var pendingLyricsImport = false
    @State private var isSeeking = false
    @State private var scrub: Double = 0
    @State private var lines: [LyricLine] = []
    @AppStorage("lyricOffset") private var offset: Double = 0
    private var activeLyric: String {
        preferences.values.syncedLyrics ? (lines.last { $0.time <= clock.position + offset }?.text ?? "Lyrics ›") : (lines.first?.text ?? "Lyrics ›")
    }
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700
            let artworkSide = min(geometry.size.width - 60,
                                  compact ? max(100, geometry.size.height - 450) : 300)
            let hasArtwork = playback.current?.artworkFile != nil || playback.current?.artworkURL != nil
            let hero = preferences.values.fullBleedArtwork && hasArtwork
            let heroHeight = min(geometry.size.height * (compact ? 0.45 : 0.55), 540)
            ZStack(alignment: .top) {
                if preferences.values.fullBleedArtwork && !preferences.values.reduceDynamicBlur {
                    Artwork(track: playback.current, radius: 0)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().blur(radius: 65).overlay(Color.black.opacity(0.6)).ignoresSafeArea()
                } else { Color.black.ignoresSafeArea() }
                if hero {
                    Artwork(track: playback.current, radius: 0)
                        .frame(width: geometry.size.width, height: heroHeight)
                        .clipped()
                        .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.58), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                ScrollView {
                    VStack(spacing: compact ? 12 : 20) {
                        HStack {
                            Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Close player")
                            Spacer(); if !preferences.values.hideSongStatus { Text(playback.current?.isLocal == false ? "Playing from " + (playback.current?.sourceName ?? "online source") : "Playing from your library").font(.caption.weight(.semibold)) }; Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                        if let track = playback.current {
                            if hero {
                                Color.clear.frame(height: max(0, heroHeight - (compact ? 105 : 115)))
                            } else {
                                Artwork(track: track, radius: 18)
                                    .frame(width: artworkSide, height: artworkSide)
                            }
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(track.title).font(.system(size: 22, weight: .bold)).tracking(-0.4).lineLimit(2)
                                    Text(track.artist).font(.title3).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                                }
                                Spacer()
                                Button { library.toggleFavorite(track.id) } label: {
                                    Image(systemName: library.snapshot.favorites.contains(track.id) ? "heart.fill" : "heart").font(.title2).frame(width: 48, height: 48)
                                }.foregroundStyle(library.snapshot.favorites.contains(track.id) ? AndroidDesign.accent : .white).accessibilityLabel("Toggle favorite")
                                trackOptions
                            }
                            Button { showingLyrics = true } label: {
                                HStack { Text(activeLyric).lineLimit(1).font(.subheadline.weight(.semibold)); Spacer(); Image(systemName: "chevron.right") }.frame(minHeight: 44)
                            }.buttonStyle(.plain)
                            VStack(spacing: 4) {
                                Slider(value: Binding(get: { isSeeking ? scrub : min(clock.position, max(clock.duration, 1)) }, set: { scrub = $0 }), in: 0...max(clock.duration, 1)) { editing in
                                    if editing { scrub = clock.position; isSeeking = true }
                                    else { playback.seek(scrub); isSeeking = false }
                                }.tint(.white).accessibilityLabel("Playback position")
                                HStack { Text(clockText(isSeeking ? scrub : clock.position)); Spacer(); Text("−" + clockText(max(0, clock.duration - (isSeeking ? scrub : clock.position)))) }.font(.caption).foregroundStyle(.white.opacity(0.6)).monospacedDigit()
                            }
                            HStack {
                                Spacer()
                                Button { playback.previous() } label: { Image(systemName: "backward.fill").font(.system(size: 30)).frame(width: 48, height: 60) }.accessibilityLabel("Previous track")
                                Spacer()
                                Button { playback.toggle() } label: {
                                    Group { if playback.isLoading { ProgressView().tint(.white) } else { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 43)) } }.frame(width: 64, height: 64)
                                }.accessibilityLabel(playback.isPlaying ? "Pause" : "Play").accessibilityIdentifier("player.transport")
                                Spacer()
                                Button { playback.next() } label: { Image(systemName: "forward.fill").font(.system(size: 30)).frame(width: 48, height: 60) }.accessibilityLabel("Next track")
                                Spacer()
                            }
                            if !preferences.values.hideVolumeBar { SystemVolumeSlider().frame(height: 34).accessibilityLabel("System volume") }
                            HStack {
                                Button { showingLyrics = true } label: { Image(systemName: "text.bubble").font(.title2).frame(width: 50, height: 44) }.accessibilityLabel("Lyrics")
                                Spacer()
                                AirPlayPicker().frame(width: 50, height: 44).accessibilityLabel("AirPlay output")
                                Spacer()
                                Button { showingQueue = true } label: { Image(systemName: "list.bullet").font(.title2).frame(width: 50, height: 44) }.accessibilityLabel("Play queue")
                            }
                            Text("This phone").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                            if let deadline = playback.sleepDeadline { Text("Sleep timer · \(deadline, style: .relative)").font(.caption).foregroundStyle(.white.opacity(0.6)) }
                        } else { EmptyStateView("Nothing playing", systemImage: "music.note") }
                    }
                    // Remote artwork and UIKit route/volume views must never
                    // dictate an unbounded ideal width for the vertical scroll.
                    .frame(width: max(0, geometry.size.width - 60))
                    .padding(.horizontal, 30).padding(.bottom, 20)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .foregroundStyle(.white).preferredColorScheme(.dark)
        }
        .task(id: playback.current?.id) { await fetchLyricsIfNeeded(); refreshLyrics() }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ActivitySheet(items: [shareURL]) } }
        .onChange(of: library.tracks) { _ in refreshLyrics() }
        .sheet(isPresented: $showingTrackOptions, onDismiss: {
            let action = deferredTrackAction; deferredTrackAction = nil; action?()
        }) {
            CompatibleNavigation {
                PlayerTrackControls(importAction: { afterTrackControls { importingLyrics = true } }, shareAction: { url in afterTrackControls { shareURL = url } })
            }
        }
        .sheet(isPresented: $showingQueue) { CompatibleNavigation { QueueView() } }
        .sheet(isPresented: $showingLyrics, onDismiss: {
            if pendingLyricsImport { pendingLyricsImport = false; importingLyrics = true }
        }) { CompatibleNavigation { LyricsView(importAction: { pendingLyricsImport = true; showingLyrics = false }) } }
        .fileImporter(isPresented: $importingLyrics, allowedContentTypes: [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]) { result in
            switch result {
            case .success(let url): if let id = playback.current?.id {
                library.importLyrics(url, for: id); refreshLyrics()
                if let message = library.error { playback.error = message; library.error = nil }
            }
            case .failure(let error): playback.error = error.localizedDescription
            }
        }
        .alert("Playback needs attention", isPresented: Binding(get: { playback.error != nil }, set: { if !$0 { playback.error = nil } })) {
            Button("Retry") { playback.error = nil; playback.retry() }
            Button("OK", role: .cancel) { playback.error = nil }
        } message: { Text(playback.error ?? "") }
    }
    private var trackOptions: some View {
        Button { showingTrackOptions = true } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                .background(.white.opacity(0.13), in: Circle())
        }.accessibilityLabel("Track options")
    }
    private func afterTrackControls(_ action: @escaping () -> Void) {
        deferredTrackAction = action; showingTrackOptions = false
    }
    private func fetchLyricsIfNeeded() async {
        guard let track = playback.current, let videoID = track.videoID, library.lyricText(track.id).isEmpty else { return }
        // Absence of lyrics is normal. Never replace imported lyrics or show a
        // playback error just because this separate provider call failed.
        if let text = try? await MusicCatalog.shared.lyrics(videoID), !text.isEmpty, !Task.isCancelled {
            library.setLyrics(text, for: track)
        }
    }
    private func refreshLyrics() {
        guard let id = playback.current?.id else { lines = []; return }
        lines = LRCParser.parse(library.lyricText(id))
    }
}
// Bounded artwork-backed sheet, matching the Android track-actions layout.
// Only implemented capabilities are exposed; no pretend video/DSP/account controls.
struct PlayerTrackControls: View {
    @EnvironmentObject private var preferences: PreferenceStore
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let importAction: () -> Void
    let shareAction: (URL) -> Void
    private func row(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 26)
            Text(title).font(.system(size: 16))
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).contentShape(Rectangle())
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                if !preferences.values.reduceDynamicBlur {
                    Artwork(track: playback.current, radius: 0)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .blur(radius: 55).overlay(Color.black.opacity(0.78)).ignoresSafeArea()
                }
                ScrollView {
                    VStack(spacing: 0) {
                        Capsule().fill(.white.opacity(0.35)).frame(width: 36, height: 4).padding(.top, 10).padding(.bottom, 16)
                        if let track = playback.current {
                            HStack(spacing: 14) {
                                Artwork(track: track, radius: 8).frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                                    Text(track.artist).font(.system(size: 14)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close track controls")
                            }.padding(.bottom, 16)
                            Divider().overlay(Color.white.opacity(0.08))
                            sourceActions(track)
                            queueActions(track)
                            playbackActions
                            RouteLink { SettingDetail(title: "Lyrics").navigationBarHidden(false) } label: { row("Lyrics offset", "slider.horizontal.3") }
                            Button(action: importAction) { row("Import lyrics (.lrc / .txt)", "text.bubble") }
                            if track.isLocal, let url = library.file(track.audioFile) {
                                Button { shareAction(url) } label: { row("Share audio file", "square.and.arrow.up") }
                            } else if let id = track.videoID, let url = URL(string: "https://music.youtube.com/watch?v=" + id) {
                                Button { shareAction(url) } label: { row("Share song", "square.and.arrow.up") }
                            }
                        }
                    }.frame(width: max(0, geometry.size.width - 48)).padding(.horizontal, 24).padding(.bottom, 24)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.foregroundStyle(.white).tint(.white).preferredColorScheme(.dark).navigationBarHidden(true)
    }
    @ViewBuilder private func sourceActions(_ track: Track) -> some View {
        if !track.isLocal, track.hasOnlineSource {
            Button { downloads.enqueue(track); dismiss() } label: { row("Download", "arrow.down.to.line") }
            Button { playback.retry(); dismiss() } label: { row("Retry stream", "arrow.clockwise") }
        }
        if track.videoID != nil {
            Button { playback.startRadio(track); dismiss() } label: { row("Start radio", "dot.radiowaves.left.and.right") }
        }
    }
    @ViewBuilder private func queueActions(_ track: Track) -> some View {
        Button { playback.enqueue(track, next: true); dismiss() } label: { row("Play next", "text.line.first.and.arrowtriangle.forward") }
        Button { playback.enqueue(track); dismiss() } label: { row("Add to queue", "text.badge.plus") }
        if let id = track.albumBrowseID { RouteLink { CatalogBrowseView(id: id, title: track.album).navigationBarHidden(false) } label: { row("Open album", "opticaldisc") } }
        if let id = track.artistBrowseID { RouteLink { CatalogBrowseView(id: id, title: track.artist).navigationBarHidden(false) } label: { row("Open artist", "person.fill") } }
        if !library.snapshot.playlists.isEmpty {
            Menu {
                ForEach(library.snapshot.playlists) { list in Button(list.name) { library.add(track.id, to: list.id); dismiss() } }
            } label: { row("Add to playlist", "music.note.list") }
        }
    }
    private var playbackActions: some View {
        Group {
            Button { playback.shuffle.toggle() } label: { row(playback.shuffle ? "Shuffle: On" : "Shuffle: Off", "shuffle") }
            Button { playback.repeatMode = playback.repeatMode == .off ? .all : (playback.repeatMode == .all ? .one : .off) } label: { row("Repeat: " + playback.repeatMode.rawValue, playback.repeatMode == .one ? "repeat.1" : "repeat") }
            Menu {
                ForEach([15, 30, 45, 60], id: \.self) { minutes in Button("\(minutes) minutes") { playback.setSleep(minutes: minutes); dismiss() } }
                Button("Cancel timer") { playback.setSleep(minutes: nil); dismiss() }
            } label: { row("Sleep timer", "moon.fill") }
        }
    }
}
struct QueueView: View {
    @EnvironmentObject var playback: PlaybackStore
    @EnvironmentObject var clock: PlaybackClock
    var body: some View {
        List {
            ForEach(Array(playback.queue.enumerated()), id: \.offset) { _, track in
                Button { playback.play(track, in: playback.queue) } label: {
                    HStack { Artwork(track: track, radius: 8).frame(width: 48, height: 48); VStack(alignment: .leading) { Text(track.title).lineLimit(1); Text(track.artist).foregroundStyle(.secondary).font(.caption) }; Spacer(); if playback.current?.id == track.id { Image(systemName: "speaker.wave.2.fill").foregroundStyle(.pink) } }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Play queue")
    }
}
struct LyricsView: View {
    @EnvironmentObject private var preferences: PreferenceStore
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var playback: PlaybackStore
    @EnvironmentObject var clock: PlaybackClock
    let importAction: () -> Void
    @AppStorage("lyricOffset") private var offset: Double = 0
    @State private var text = ""
    @State private var lines: [LyricLine] = []
    private var activeID: Int? { lines.last { $0.time <= clock.position + offset }?.id }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if text.isEmpty {
                        EmptyStateView("Bring your lyrics", systemImage: "text.bubble", description: Text("Import a UTF-8 .lrc file for synced lyrics, or .txt for plain lyrics."))
                        Button("Import lyrics", action: importAction).buttonStyle(.borderedProminent)
                    } else if lines.isEmpty { Text(text).font(.title2.weight(.semibold)).textSelection(.enabled) }
                    else {
                        ForEach(lines) { line in
                            Button { if preferences.values.syncedLyrics { playback.seek(max(0, line.time - offset)) } } label: {
                                Text(line.text.isEmpty ? "♪" : line.text).font(.title2.bold()).foregroundStyle(!preferences.values.syncedLyrics || activeID == line.id ? Color.primary : Color.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6).blur(radius: preferences.values.lyricsBlur && preferences.values.syncedLyrics && activeID != line.id ? 1.5 : 0)
                            }.buttonStyle(.plain).id(line.id)
                        }
                    }
                }.padding(24)
            }.onChange(of: activeID) { id in if preferences.values.syncedLyrics, let id { if preferences.values.reduceAnimation || UIAccessibility.isReduceMotionEnabled { proxy.scrollTo(id, anchor: .center) } else { withAnimation { proxy.scrollTo(id, anchor: .center) } } } }
        }.navigationTitle("Lyrics").toolbar { Button("Import", action: importAction) }
            .task(id: playback.current?.id) {
                if let track = playback.current {
                    text = library.lyricText(track.id)
                    if text.isEmpty, let id = track.videoID, let fetched = try? await MusicCatalog.shared.lyrics(id), !Task.isCancelled {
                        library.setLyrics(fetched, for: track); text = fetched
                    }
                    lines = LRCParser.parse(text)
                }
            }
    }
}
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { let view = MPVolumeView(); view.showsRouteButton = false; return view }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
struct AirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.tintColor = .white; view.activeTintColor = .systemPink; return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
