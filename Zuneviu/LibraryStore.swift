import Foundation
import Combine
@preconcurrency import AVFoundation

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var snapshot = LibrarySnapshot()
    @Published var error: String?
    @Published var isImporting = false
    private(set) var storageReady = true
    private var uncommittedListening: Double = 0
    let root: URL
    var tracks: [Track] { snapshot.tracks }
    var favorites: [Track] { tracks.filter { snapshot.favorites.contains($0.id) } }
    var recent: [Track] { snapshot.history.compactMap { id in tracks.first { $0.id == id } } }
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Zuneviu", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            let file = self.root.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: file.path) {
                snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: file))
            }
        } catch { storageReady = false; self.error = "Could not open your saved library. Your files have not been deleted. \(error.localizedDescription)" }
    }
    func file(_ name: String) -> URL { root.appendingPathComponent(name) }
    @discardableResult func save() -> Bool {
        guard storageReady else { return false }
        do {
            var persisted = snapshot
            persisted.listenedSeconds += uncommittedListening
            try JSONEncoder().encode(persisted).write(to: file("library.json"), options: .atomic)
            if uncommittedListening > 0 { snapshot = persisted; uncommittedListening = 0 }
            return true
        }
        catch { self.error = "Could not save library: \(error.localizedDescription)"; return false }
    }
    var onDevice: [Track] { tracks.filter(\.isLocal) }
    var downloads: [Track] { tracks.filter { $0.downloadedAt != nil && $0.isLocal } }
    func clearHistory() { snapshot.history = []; save() }
    func installDownload(_ track: Track, temporaryFile: URL) async throws {
        guard storageReady else { throw MusicServiceError.unavailable("The library cannot be saved.") }
        if self.track(track.id)?.isLocal == true { return }
        // URLSession temporary paths have no media extension. AVFoundation can
        // reject a valid AAC/MP4 file at such a URL. Stage a typed app-owned
        // copy first, then validate that exact file before committing metadata.
        let handle = try FileHandle(forReadingFrom: temporaryFile)
        let prefix = try handle.read(upToCount: 16) ?? Data(); try handle.close()
        let magic = String(decoding: prefix, as: UTF8.self)
        let adts = prefix.count >= 2 && prefix[0] == 0xff && (prefix[1] & 0xf6) == 0xf0
        let mpeg = prefix.count >= 2 && prefix[0] == 0xff && (prefix[1] & 0xe0) == 0xe0
        let ext = magic.hasPrefix("RIFF") ? "wav" : magic.hasPrefix("fLaC") ? "flac" : magic.hasPrefix("ID3") ? "mp3" : adts ? "aac" : mpeg ? "mp3" : "m4a"
        let filename = "download-" + track.id.uuidString + "-" + UUID().uuidString + "." + ext
        let destination = file(filename)
        try FileManager.default.copyItem(at: temporaryFile, to: destination)
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: destination) } }
        let asset = AVURLAsset(url: destination)
        guard try await asset.load(.isPlayable) else { throw MusicServiceError.unavailable("The downloaded file is not playable audio.") }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw MusicServiceError.unavailable("The source returned no audio track.") }
        let seconds = try await asset.load(.duration).seconds
        guard seconds.isFinite, seconds > 0,
              track.duration <= 0 || seconds >= track.duration - max(3, track.duration * 0.05) else {
            throw MusicServiceError.unavailable("The downloaded audio appears incomplete. No library entry was added.")
        }
        try Task.checkCancellation()
        let previous = snapshot
        var downloaded = self.track(track.id) ?? track; downloaded.audioFile = filename; downloaded.downloadedAt = Date(); downloaded.duration = seconds
        if let index = snapshot.tracks.firstIndex(where: { $0.id == track.id }) { snapshot.tracks[index] = downloaded }
        else { snapshot.tracks.append(downloaded) }
        guard save() else { snapshot = previous; try? FileManager.default.removeItem(at: destination); throw MusicServiceError.unavailable("Could not save this download. The original library was kept.") }
        committed = true
        var resource = destination; var values = URLResourceValues(); values.isExcludedFromBackup = true; try? resource.setResourceValues(values)
    }
    // Removing a source download must not erase likes, playlist membership,
    // history or imported lyrics. Imports use the separate remove-from-app flow.
    @discardableResult func removeDownload(_ id: UUID) -> Bool {
        guard storageReady, let index = snapshot.tracks.firstIndex(where: { $0.id == id }),
              snapshot.tracks[index].downloadedAt != nil, snapshot.tracks[index].hasOnlineSource else { return false }
        let previous = snapshot, filename = snapshot.tracks[index].audioFile
        snapshot.tracks[index].audioFile = ""; snapshot.tracks[index].downloadedAt = nil
        guard save() else { snapshot = previous; return false }
        if !filename.isEmpty { try? FileManager.default.removeItem(at: file(filename)) }
        return true
    }
    func remember(_ track: Track) {
        guard storageReady, !snapshot.tracks.contains(where: { $0.id == track.id }) else { return }
        snapshot.tracks.append(track); save()
    }
    func setLyrics(_ text: String, for track: Track) {
        guard storageReady, !text.isEmpty else { return }
        remember(track)
        guard let index = snapshot.tracks.firstIndex(where: { $0.id == track.id }) else { return }
        do {
            let name = "\(track.id.uuidString).lrc"
            try Data(text.utf8).write(to: file(name), options: .atomic)
            snapshot.tracks[index].lyricsFile = name; save()
        } catch { self.error = error.localizedDescription }
    }
    func track(_ id: UUID) -> Track? { tracks.first { $0.id == id } }
    func toggleFavorite(_ id: UUID) {
        if snapshot.favorites.contains(id) { snapshot.favorites.remove(id) } else { snapshot.favorites.insert(id) }
        save()
    }
    func recordPlay(_ id: UUID) {
        snapshot.history.removeAll { $0 == id }; snapshot.history.insert(id, at: 0)
        snapshot.history = Array(snapshot.history.prefix(100)); save()
    }
    func addListening(_ seconds: Double) {
        guard storageReady, seconds.isFinite, seconds > 0 else { return }
        uncommittedListening += seconds
    }
    func createPlaylist(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        snapshot.playlists.append(Playlist(name: trimmed)); save()
    }
    func add(_ track: UUID, to playlist: UUID) {
        guard let index = snapshot.playlists.firstIndex(where: { $0.id == playlist }), !snapshot.playlists[index].trackIDs.contains(track) else { return }
        snapshot.playlists[index].trackIDs.append(track); save()
    }
    func deletePlaylist(_ id: UUID) { snapshot.playlists.removeAll { $0.id == id }; save() }
    func remove(_ id: UUID) {
        guard storageReady, let track = track(id) else { return }
        let previous = snapshot
        snapshot.tracks.removeAll { $0.id == id }; snapshot.favorites.remove(id); snapshot.history.removeAll { $0 == id }
        for index in snapshot.playlists.indices { snapshot.playlists[index].trackIDs.removeAll { $0 == id } }
        // Save the manifest first. Never delete the user's original Files document.
        guard save() else { snapshot = previous; return }
        for name in [track.audioFile, track.artworkFile, track.lyricsFile].compactMap({ $0 }).filter({ !$0.isEmpty }) { try? FileManager.default.removeItem(at: file(name)) }
    }
    func importAudio(_ urls: [URL]) async {
        guard storageReady, !isImporting else { return }; isImporting = true
        defer { isImporting = false }
        var failures: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let id = UUID()
            let name = "\(id.uuidString).\(url.pathExtension.lowercased())"
            let destination = file(name)
            var artworkName: String?
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                let asset = AVURLAsset(url: destination)
                guard try await asset.load(.isPlayable) else { throw ImportError.unplayable }
                let duration = try await asset.load(.duration).seconds
                var title = url.deletingPathExtension().lastPathComponent
                var artist = "Unknown artist", album = "Local Music"
                for item in (try? await asset.load(.commonMetadata)) ?? [] {
                    switch item.commonKey {
                    case .commonKeyTitle: if let text = try? await item.load(.stringValue) { title = text }
                    case .commonKeyArtist: if let text = try? await item.load(.stringValue) { artist = text }
                    case .commonKeyAlbumName: if let text = try? await item.load(.stringValue) { album = text }
                    case .commonKeyArtwork:
                        if let data = try? await item.load(.dataValue) {
                            let art = "\(id.uuidString).art"
                            try data.write(to: file(art), options: .atomic); artworkName = art
                        }
                    default: break
                    }
                }
                snapshot.tracks.append(Track(id: id, title: title, artist: artist, album: album, audioFile: name, artworkFile: artworkName, duration: duration.isFinite ? duration : 0, importedAt: Date()))
                if !save() {
                    snapshot.tracks.removeAll { $0.id == id }
                    throw CocoaError(.fileWriteUnknown)
                }
            } catch {
                try? FileManager.default.removeItem(at: destination)
                if let artworkName { try? FileManager.default.removeItem(at: file(artworkName)) }
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty { error = failures.joined(separator: "\n") }
    }
    func importLyrics(_ url: URL, for id: UUID) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            guard let index = snapshot.tracks.firstIndex(where: { $0.id == id }) else { return }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else { throw ImportError.lyricsEncoding }
            let name = "\(id.uuidString).lrc"
            try Data(text.utf8).write(to: file(name), options: .atomic)
            snapshot.tracks[index].lyricsFile = name; save()
        } catch { self.error = error.localizedDescription }
    }
    func lyricText(_ id: UUID) -> String {
        guard let name = track(id)?.lyricsFile else { return "" }
        return (try? String(contentsOf: file(name), encoding: .utf8)) ?? ""
    }
    enum ImportError: LocalizedError {
        case unplayable, lyricsEncoding
        var errorDescription: String? {
            switch self { case .unplayable: return "This file cannot be played by iOS. Try MP3, M4A, WAV or FLAC without DRM."
            case .lyricsEncoding: return "Lyrics must be a UTF-8 .lrc or .txt file." }
        }
    }
}
