import Foundation
import Combine

enum DownloadState: String, Codable { case queued, waitingForWifi, resolving, downloading, verifying, completed, cancelled, failed, interrupted }
struct DownloadJob: Identifiable, Codable {
    var id: UUID { track.id }
    var track: Track
    var state: DownloadState = .queued
    var receivedBytes: Int64 = 0
    var expectedBytes: Int64 = -1
    var message: String?
    var createdAt = Date()
    var progress: Double? { expectedBytes > 0 ? min(1, Double(receivedBytes) / Double(expectedBytes)) : nil }
}

// One real URLSession download task per transfer. Signed media URLs remain in
// memory; the persisted queue stores track metadata only and re-resolves retry.
final class DownloadTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let maximumBytes: Int64 = 512 * 1024 * 1024
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var completed: Result<URL, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private let progress: @Sendable (Int64, Int64) -> Void
    init(progress: @escaping @Sendable (Int64, Int64) -> Void) { self.progress = progress }
    func fetch(_ url: URL, wifiOnly: Bool) async throws -> URL {
        guard url.scheme == "https" else { throw MusicServiceError.unavailable("Only secure HTTPS downloads are allowed.") }
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let completed { lock.unlock(); continuation.resume(with: completed); return }
                self.continuation = continuation
                let config = URLSessionConfiguration.ephemeral
                config.httpCookieStorage = nil; config.urlCache = nil
                config.allowsCellularAccess = !wifiOnly
                config.allowsExpensiveNetworkAccess = !wifiOnly
                config.allowsConstrainedNetworkAccess = !wifiOnly
                config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 600
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.session = session; let task = session.downloadTask(with: url); self.task = task
                lock.unlock(); task.resume()
            }
        }, onCancel: { self.finish(.failure(CancellationError())) })
    }
    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        guard completed == nil else { lock.unlock(); if case .success(let url) = result { try? FileManager.default.removeItem(at: url) }; return }
        completed = result; let continuation = self.continuation; self.continuation = nil
        let session = self.session; self.session = nil; task = nil
        lock.unlock()
        session?.invalidateAndCancel(); continuation?.resume(with: result)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > Self.maximumBytes || totalBytesExpectedToWrite > Self.maximumBytes {
            finish(.failure(MusicServiceError.unavailable("Download exceeded the 512 MB per-track limit."))); return
        }
        progress(totalBytesWritten, totalBytesExpectedToWrite)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else { throw MusicServiceError.unavailable("The source did not return a complete downloadable file.") }
            let type = (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            guard !type.contains("text/"), !type.contains("json"), !type.contains("mpegurl"), !type.contains("dash+xml") else { throw MusicServiceError.unavailable("This source returned a playlist or error, not an offline audio file.") }
            let size = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.int64Value ?? 0
            guard size > 0, size <= Self.maximumBytes, response.expectedContentLength <= 0 || size == response.expectedContentLength else { throw MusicServiceError.unavailable("The downloaded file is empty, incomplete or too large.") }
            let handle = try FileHandle(forReadingFrom: location); let prefix = try handle.read(upToCount: 256) ?? Data(); try handle.close()
            let header = String(decoding: prefix, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.hasPrefix("#EXTM3U"), !header.hasPrefix("<MPD"), !header.hasPrefix("<?xml"), !header.lowercased().hasPrefix("<!doctype") else { throw MusicServiceError.unavailable("Manifest downloads require offline packaging, which is not supported yet.") }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("Zuneviu-download-" + UUID().uuidString)
            try FileManager.default.moveItem(at: location, to: copy)
            finish(.success(copy))
        } catch { finish(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
    }
}

@MainActor final class DownloadManager: ObservableObject {
    typealias Resolver = @Sendable (Track, AudioQuality) async throws -> URL
    typealias Fetcher = @Sendable (URL, Bool, @escaping @Sendable (Int64, Int64) -> Void) async throws -> URL
    @Published private(set) var jobs: [DownloadJob] = []
    @Published private(set) var persistenceError: String?
    private let library: LibraryStore
    private let preferences: PreferenceStore
    private let network: NetworkStatus
    private let resolver: Resolver
    private let fetcher: Fetcher
    private var task: Task<Void, Never>?
    private var active: UUID?
    private var subscriptions = Set<AnyCancellable>()
    private var progressAt = Date.distantPast
    private var storageReady = true
    private var queueFile: URL { library.file("download-queue.json") }
    init(library: LibraryStore, preferences: PreferenceStore, network: NetworkStatus,
         resolver: @escaping Resolver = { track, quality in
             return try await AudioSourceResolver.resolve(track, quality: quality)
         }, fetcher: @escaping Fetcher = { url, wifiOnly, progress in try await DownloadTransfer(progress: progress).fetch(url, wifiOnly: wifiOnly) }) {
        self.library = library; self.preferences = preferences; self.network = network; self.resolver = resolver; self.fetcher = fetcher
        do {
            if FileManager.default.fileExists(atPath: queueFile.path) {
                jobs = try JSONDecoder().decode([DownloadJob].self, from: Data(contentsOf: queueFile))
                for index in jobs.indices where ![.completed, .failed, .cancelled, .interrupted].contains(jobs[index].state) {
                    jobs[index].state = .interrupted; jobs[index].message = "App restarted. Retry to request a fresh source URL."
                }
            }
        } catch { storageReady = false; persistenceError = "Could not read the download queue. Its original file has been preserved." }
        network.$kind.dropFirst().sink { [weak self] _ in Task { @MainActor in self?.pump() } }.store(in: &subscriptions)
        preferences.$values.dropFirst().sink { [weak self] _ in Task { @MainActor in self?.pump() } }.store(in: &subscriptions)
    }
    func enqueue(_ track: Track) {
        guard track.saavnID == nil || preferences.values.saavnEnabled else { return }
        guard storageReady, library.storageReady, !track.isLocal, library.track(track.id)?.isLocal != true else { return }
        guard !jobs.contains(where: { $0.id == track.id && [.queued, .waitingForWifi, .resolving, .downloading, .verifying].contains($0.state) }) else { return }
        jobs.removeAll { $0.id == track.id }; jobs.append(DownloadJob(track: track)); persist(); pump()
    }
    func retry(_ id: UUID) { guard let track = jobs.first(where: { $0.id == id })?.track else { return }; enqueue(track) }
    func cancel(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }), ![.completed, .failed, .cancelled, .interrupted].contains(jobs[index].state) else { return }
        jobs[index].state = .cancelled; jobs[index].message = "Cancelled"
        if active == id { task?.cancel() }; persist()
    }
    @discardableResult func removeOfflineCopy(_ id: UUID) -> Bool {
        guard library.removeDownload(id) else { return false }
        jobs.removeAll { $0.id == id && $0.state == .completed }; persist()
        return true
    }
    func clearFinished() { jobs.removeAll { [.completed, .cancelled].contains($0.state) }; persist() }
    private func pump() {
        guard task == nil, storageReady, let index = jobs.firstIndex(where: { [.queued, .waitingForWifi].contains($0.state) }) else { return }
        let wifiOnly = preferences.values.wifiOnlyDownloads
        guard !wifiOnly || network.allowsWifiOnlyDownload else { jobs[index].state = .waitingForWifi; jobs[index].message = "Waiting for unmetered Wi-Fi or Ethernet"; persist(); return }
        guard network.kind != .offline else { jobs[index].state = .waitingForWifi; jobs[index].message = "Waiting for a connection"; return }
        let track = jobs[index].track, quality = preferences.values.downloadQuality
        if track.saavnID != nil && !preferences.values.saavnEnabled {
            jobs[index].state = .failed; jobs[index].message = "JioSaavn was disabled. Enable it in Sources before retrying."; persist(); pump(); return
        }
        active = track.id; update(track.id, state: .resolving, message: "Requesting audio from the source…")
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.active = nil; self.task = nil; self.pump() }
            var temporary: URL?
            defer { if let temporary { try? FileManager.default.removeItem(at: temporary) } }
            do {
                let url = try await resolver(track, quality); try Task.checkCancellation()
                update(track.id, state: .downloading, message: nil)
                temporary = try await fetcher(url, wifiOnly, { [weak self] bytes, expected in
                    Task { @MainActor in self?.progress(track.id, bytes: bytes, expected: expected) }
                })
                try Task.checkCancellation(); update(track.id, state: .verifying, message: "Verifying complete playable audio…")
                try await library.installDownload(track, temporaryFile: temporary!)
                update(track.id, state: .completed, message: "Available offline")
            } catch is CancellationError { update(track.id, state: .cancelled, message: "Cancelled") }
            catch { update(track.id, state: .failed, message: "Download failed: " + error.localizedDescription) }
        }
    }
    private func progress(_ id: UUID, bytes: Int64, expected: Int64) {
        guard Date().timeIntervalSince(progressAt) >= 0.2, let index = jobs.firstIndex(where: { $0.id == id && $0.state == .downloading }) else { return }
        progressAt = Date(); jobs[index].receivedBytes = bytes; jobs[index].expectedBytes = expected
    }
    private func update(_ id: UUID, state: DownloadState, message: String?) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = state; jobs[index].message = message; persist()
    }
    private func persist() {
        guard storageReady else { return }
        do { try JSONEncoder().encode(jobs).write(to: queueFile, options: .atomic) }
        catch { persistenceError = "Could not save the download queue. Existing audio has not been removed." }
    }
}
