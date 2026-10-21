import Foundation
import Combine
import AVFoundation
import MediaPlayer
import UIKit

// High-frequency clock changes are isolated from the library/navigation graph.
@MainActor final class PlaybackClock: ObservableObject {
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    func setPosition(_ value: Double) { if abs(position - value) > 0.001 { position = value } }
    func setDuration(_ value: Double) { if abs(duration - value) > 0.01 { duration = value } }
}

enum RepeatMode: String, CaseIterable { case off, all, one }

@MainActor final class PlaybackStore: ObservableObject {
    @Published private(set) var current: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    let clock = PlaybackClock()
    var position: Double { get { clock.position } set { clock.setPosition(newValue) } }
    var duration: Double { get { clock.duration } set { clock.setDuration(newValue) } }
    @Published private(set) var sleepDeadline: Date?
    @Published var error: String?
    @Published var shuffle = false
    @Published var repeatMode: RepeatMode = .off
    let player = AVPlayer()
    private let library: LibraryStore
    private let preferences: PreferenceStore
    private let discovery: DiscoveryStore?
    private var resolveTask: Task<Void, Never>?
    private var autoplayTask: Task<Void, Never>?
    private var autoplayID = UUID()
    private var requestID = UUID()
    private var isResolving = false
    private var tick: Any?
    private var observers: [NSObjectProtocol] = []
    private var subscriptions = Set<AnyCancellable>()
    private var itemSubscription: AnyCancellable?
    private var sleepTask: Task<Void, Never>?
    private var pendingSave: Double = 0
    private var lastNowPlayingSecond: Int = -1
    private var resumeAfterInterruption = false
    private var nowPlayingArtwork: MPMediaItemArtwork?

    init(library: LibraryStore, preferences: PreferenceStore? = nil, discovery: DiscoveryStore? = nil) {
        self.preferences = preferences ?? PreferenceStore.shared
        self.discovery = discovery
        self.library = library
        player.automaticallyWaitsToMinimizeStalling = true
        player.publisher(for: \.timeControlStatus).receive(on: DispatchQueue.main).sink { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                let playing = status == .playing
                let loading = self.isResolving || status == .waitingToPlayAtSpecifiedRate
                if self.isPlaying != playing { self.isPlaying = playing }
                if self.isLoading != loading { self.isLoading = loading }
                self.updateNowPlaying()
            }
        }.store(in: &subscriptions)
        tick = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in self?.updateTime(time.seconds) }
        }
        observers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, item === self.player.currentItem else { return }
                self.next(automatic: true)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in self?.interruption(type: type, options: options) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { self?.pause() }
            }
        })
        configureRemoteControls()
    }
    func play(_ track: Track, in tracks: [Track]) {
        queue = tracks.isEmpty ? [track] : tracks
        if !queue.contains(where: { $0.id == track.id }) { queue.insert(track, at: 0) }
        load(track)
    }
    private func load(_ requestedTrack: Track) {
        autoplayTask?.cancel(); autoplayID = UUID()
        resolveTask?.cancel(); requestID = UUID()
        let token = requestID
        let track = library.track(requestedTrack.id) ?? requestedTrack
        error = nil; isResolving = false; isLoading = false
        player.pause(); player.replaceCurrentItem(with: nil)
        if track.isLocal {
            let url = library.file(track.audioFile)
            guard FileManager.default.fileExists(atPath: url.path) else {
                current = nil; error = "Playback failed: the imported file is missing."; return
            }
            start(track, url: url)
        } else if track.hasOnlineSource {
            guard track.saavnID == nil || preferences.values.saavnEnabled else { current = nil; error = "Enable JioSaavn in Settings → Sources before playing its online results."; return }
            current = track; position = 0; duration = track.duration
            isResolving = true; isLoading = true
            resolveTask = Task { [weak self] in
                do {
                    guard let self else { return }
                    let network = NetworkStatus.shared
                    guard network.kind != .cellular || self.preferences.values.cellularStreamingAllowed else { throw MusicServiceError.unavailable("Cellular streaming is disabled in Audio quality settings.") }
                    let quality = (network.kind == .wifi || network.kind == .wired) ? self.preferences.values.audioQualityWifi : self.preferences.values.audioQualityCellular
                    let url = try await AudioSourceResolver.resolve(track, quality: quality)
                    try Task.checkCancellation()
                    guard self.requestID == token else { return }
                    self.isResolving = false; self.start(track, url: url)
                } catch {
                    guard !Task.isCancelled, let self, self.requestID == token else { return }
                    self.isResolving = false; self.isLoading = false; self.isPlaying = false
                    self.error = "Could not stream this song. The provider may be unavailable, require sign-in, or restrict playback in your region. Try another song or Retry."
                }
            }
        } else { current = nil; error = "This song has no audio source." }
    }
    func retry() {
        guard let current else { return }
        if let id = current.videoID {
            Task { await StreamResolver.shared.invalidate(id); load(current) }
        } else { load(current) }
    }
    private func start(_ track: Track, url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            current = track; position = 0; duration = track.duration
            nowPlayingArtwork = nil
            if let name = track.artworkFile, let image = UIImage(contentsOfFile: library.file(name).path) {
                nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
            let item = AVPlayerItem(url: url)
            let token = requestID
            itemSubscription = item.publisher(for: \.status).receive(on: DispatchQueue.main).sink { [weak self] status in
                Task { @MainActor in
                    guard let self, self.requestID == token else { return }
                    if status == .failed {
                        self.isLoading = false; self.isPlaying = false
                        self.error = "iOS could not play this audio. Try Retry or another track."
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            library.remember(track); if preferences.values.recordListeningHistory { library.recordPlay(track.id) }
            resume(); updateNowPlaying()
        } catch { self.error = "Playback failed: \(error.localizedDescription)"; isLoading = false }
    }
    func startRadio(_ track: Track) {
        guard let videoID = track.videoID else { return }
        Task {
            do {
                let songs = try await MusicCatalog.shared.radio(videoID)
                guard !songs.isEmpty else { throw MusicServiceError.noResults }
                play(songs.first(where: { $0.videoID == videoID }) ?? songs[0], in: songs)
            } catch { self.error = "Could not load song radio. Please try again." }
        }
    }
    func toggle() {
        if isPlaying || isLoading { pause() }
        else if player.currentItem == nil, let current { load(current) }
        else { resume() }
    }
    func resume() {
        guard current != nil, !isResolving else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let storedRate = UserDefaults.standard.double(forKey: "playbackRate")
            let rate = storedRate > 0 ? min(2, max(0.5, storedRate)) : 1
            player.playImmediately(atRate: Float(rate))
        } catch { self.error = error.localizedDescription }
    }
    func pause() {
        autoplayTask?.cancel(); autoplayID = UUID()
        if isResolving { resolveTask?.cancel(); requestID = UUID(); isResolving = false; isLoading = false }
        player.pause(); library.save(); updateNowPlaying()
    }
    func stop() {
        resolveTask?.cancel(); requestID = UUID(); isResolving = false; isLoading = false
        pause(); player.replaceCurrentItem(with: nil); current = nil; queue = []; position = 0; duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    func seek(_ value: Double) {
        let clamped = min(max(0, value), max(0, duration))
        position = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }
    func next(automatic: Bool = false) {
        guard let current, !queue.isEmpty else { return }
        if automatic && repeatMode == .one { seek(0); resume(); return }
        let index = queue.firstIndex(where: { $0.id == current.id }) ?? 0
        if shuffle, queue.count > 1, let track = queue.filter({ $0.id != current.id }).randomElement() { load(track); return }
        if index + 1 < queue.count { load(queue[index + 1]) }
        else if repeatMode == .all { load(queue[0]) }
        else if automatic && preferences.values.autoplay, let id = current.videoID {
            autoplayTask?.cancel(); autoplayID = UUID(); let token = autoplayID
            autoplayTask = Task {
                do {
                    let candidates = try await MusicCatalog.shared.radio(id).filter { candidate in !queue.contains(where: { $0.id == candidate.id }) }
                    guard !Task.isCancelled, self.autoplayID == token, self.current?.id == current.id, preferences.values.autoplay else { return }
                    if let next = candidates.first { play(next, in: candidates) } else { pause(); seek(0) }
                } catch { guard !Task.isCancelled, autoplayID == token else { return }; pause(); self.error = "Autoplay could not load more songs." }
            }
        } else { pause(); seek(0) }
    }
    func previous() {
        if position > 3 { seek(0); return }
        guard let current, let index = queue.firstIndex(where: { $0.id == current.id }) else { return }
        load(queue[max(0, index - 1)])
    }
    func enqueue(_ track: Track, next: Bool = false) {
        guard let current else { play(track, in: [track]); return }
        guard track.id != current.id else { return }
        queue.removeAll { $0.id == track.id }
        if next, let index = queue.firstIndex(where: { $0.id == current.id }) { queue.insert(track, at: index + 1) }
        else { queue.append(track) }
    }
    func removeFromQueue(_ id: UUID) {
        if current?.id == id { stop() }
        else { queue.removeAll { $0.id == id } }
    }
    func setSleep(minutes: Int?) {
        sleepTask?.cancel(); sleepTask = nil; sleepDeadline = nil
        guard let minutes else { return }
        sleepDeadline = Date().addingTimeInterval(Double(minutes * 60))
        sleepTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(minutes * 60) * 1_000_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.pause(); self?.sleepDeadline = nil
        }
    }
    private func updateTime(_ value: Double) {
        guard value.isFinite else { return }
        let elapsed = value - position
        if isPlaying && elapsed > 0 && elapsed < 1.5 {
            library.addListening(elapsed); if let current { discovery?.record(current, seconds: elapsed) }; pendingSave += elapsed
            if pendingSave >= 15 { library.save(); pendingSave = 0 }
        }
        position = max(0, value)
        if let measured = player.currentItem?.duration.seconds, measured.isFinite, measured > 0 { duration = measured }
        let second = Int(position)
        if second != lastNowPlayingSecond { lastNowPlayingSecond = second; updateNowPlaying() }
    }
    private func interruption(type: UInt?, options: UInt) {
        if type == AVAudioSession.InterruptionType.began.rawValue {
            resumeAfterInterruption = isPlaying; pause()
        } else if type == AVAudioSession.InterruptionType.ended.rawValue {
            if resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { resume() }
            resumeAfterInterruption = false
        }
    }
    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: current.title, MPMediaItemPropertyArtist: current.artist,
            MPMediaItemPropertyAlbumTitle: current.album, MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position, MPNowPlayingInfoPropertyPlaybackRate: player.rate]
        if let nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = nowPlayingArtwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    private func configureRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let value = event.positionTime
            Task { @MainActor in self?.seek(value) }; return .success
        }
    }
}
