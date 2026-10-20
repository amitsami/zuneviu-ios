import Foundation
import Combine
@preconcurrency import AVFoundation

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var snapshot = LibrarySnapshot()
    @Published var error: String?
    @Published var isImporting = false
    private(set) var storageReady = true
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
        do { try JSONEncoder().encode(snapshot).write(to: file("library.json"), options: .atomic); return true }
        catch { self.error = "Could not save library: \(error.localizedDescription)"; return false }
    }
    var onDevice: [Track] { tracks.filter(\.isLocal) }
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
    func addListening(_ seconds: Double) { snapshot.listenedSeconds += max(0, seconds) }
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
