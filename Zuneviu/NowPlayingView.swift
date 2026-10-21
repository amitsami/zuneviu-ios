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
            ZStack {
                if preferences.values.fullBleedArtwork && !preferences.values.reduceDynamicBlur {
                    Artwork(track: playback.current, radius: 0).blur(radius: 65).overlay(Color.black.opacity(0.6)).ignoresSafeArea()
                } else { Color.black.ignoresSafeArea() }
                ScrollView {
                    VStack(spacing: 24) {
                        HStack {
                            Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Close player")
                            Spacer(); if !preferences.values.hideSongStatus { Text(playback.current?.isLocal == false ? "Playing from " + (playback.current?.sourceName ?? "online source") : "Playing from your library").font(.caption.weight(.semibold)) }; Spacer()
                            Menu {
                                if let track = playback.current {
                                    IconButton("Import lyrics (.lrc / .txt)", systemImage: "text.bubble") { importingLyrics = true }
                                    Menu("Add to playlist") {
                                        ForEach(library.snapshot.playlists) { list in Button(list.name) { library.add(track.id, to: list.id) } }
                                    }
                                    if track.isLocal {
                                        IconButton("Share audio file", systemImage: "square.and.arrow.up") { shareURL = library.file(track.audioFile) }
                                    } else if track.hasOnlineSource {
                                        IconButton("Download", systemImage: "arrow.down.circle") { downloads.enqueue(track) }
                                        IconButton("Retry stream", systemImage: "arrow.clockwise") { playback.retry() }
                                        if let id = track.videoID {
                                            IconButton("Start radio", systemImage: "dot.radiowaves.left.and.right") { playback.startRadio(track) }
                                            IconButton("Share song", systemImage: "square.and.arrow.up") { shareURL = URL(string: "https://music.youtube.com/watch?v=" + id) }
                                        }
                                    }
                                }
                                Menu("Sleep timer") {
                                    ForEach([15, 30, 45, 60], id: \.self) { minutes in Button("\(minutes) minutes") { playback.setSleep(minutes: minutes) } }
                                    Button("Cancel timer") { playback.setSleep(minutes: nil) }
                                }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Track options")
                        }
                        if let track = playback.current {
                            Artwork(track: track, radius: 22)
                                .frame(width: min(geometry.size.width - 48, 380), height: min(geometry.size.width - 48, 380))
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(track.title).font(.title2.bold()).lineLimit(2)
                                    Text(track.artist).font(.title3).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                                }
                                Spacer()
                                Button { library.toggleFavorite(track.id) } label: {
                                    Image(systemName: library.snapshot.favorites.contains(track.id) ? "heart.fill" : "heart").font(.title2).frame(width: 48, height: 48)
                                }.foregroundStyle(library.snapshot.favorites.contains(track.id) ? Color.pink : .white).accessibilityLabel("Toggle favorite")
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
                                Button { playback.shuffle.toggle() } label: { Image(systemName: "shuffle").frame(width: 44, height: 44).foregroundStyle(playback.shuffle ? Color.pink : .white.opacity(0.6)) }.accessibilityLabel("Shuffle").accessibilityValue(playback.shuffle ? "On" : "Off")
                                Spacer()
                                Button { playback.previous() } label: { Image(systemName: "backward.fill").font(.system(size: 30)).frame(width: 48, height: 60) }.accessibilityLabel("Previous track")
                                Spacer()
                                Button { playback.toggle() } label: {
                                    Group { if playback.isLoading { ProgressView().tint(.white) } else { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 43)) } }.frame(width: 64, height: 64)
                                }.accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                                Spacer()
                                Button { playback.next() } label: { Image(systemName: "forward.fill").font(.system(size: 30)).frame(width: 48, height: 60) }.accessibilityLabel("Next track")
                                Spacer()
                                Button {
                                    playback.repeatMode = playback.repeatMode == .off ? .all : (playback.repeatMode == .all ? .one : .off)
                                } label: { Image(systemName: playback.repeatMode == .one ? "repeat.1" : "repeat").frame(width: 44, height: 44).foregroundStyle(playback.repeatMode != .off ? Color.pink : .white.opacity(0.6)) }.accessibilityLabel("Repeat").accessibilityValue(playback.repeatMode.rawValue)
                            }
                            if !preferences.values.hideVolumeBar { SystemVolumeSlider().frame(height: 34).accessibilityLabel("System volume") }
                            HStack {
                                Button { showingLyrics = true } label: { Image(systemName: "text.bubble").font(.title2).frame(width: 50, height: 44) }.accessibilityLabel("Lyrics")
                                Spacer()
                                AirPlayPicker().frame(width: 50, height: 44).accessibilityLabel("AirPlay output")
                                Spacer()
                                Button { showingQueue = true } label: { Image(systemName: "list.bullet").font(.title2).frame(width: 50, height: 44) }.accessibilityLabel("Play queue")
                            }
                            if let deadline = playback.sleepDeadline { Text("Sleep timer · \(deadline, style: .relative)").font(.caption).foregroundStyle(.white.opacity(0.6)) }
                        } else { EmptyStateView("Nothing playing", systemImage: "music.note") }
                    }.padding(.horizontal, 24).padding(.bottom, 28)
                }
            }.foregroundStyle(.white).preferredColorScheme(.dark)
        }
        .task(id: playback.current?.id) { await fetchLyricsIfNeeded(); refreshLyrics() }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ActivitySheet(items: [shareURL]) } }
        .onChange(of: library.tracks) { _ in refreshLyrics() }
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
