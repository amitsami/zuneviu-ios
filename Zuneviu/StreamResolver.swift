import Foundation
import YouTubeKit

// Native on-device extraction only. No hosted proxy, API key, downloaded plugin,
// or remote code execution service. No resolved URL leaves this process.
actor StreamResolver {
    static let shared = StreamResolver()
    private var cache: [String: (URL, Date)] = [:]
    func invalidate(_ id: String) { cache[id] = nil }
    func resolve(_ id: String) async throws -> URL {
        guard id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil else { throw MusicServiceError.invalidResponse }
        if let (url, date) = cache[id], Date().timeIntervalSince(date) < 120 { return url }
        let streams = try await YouTube(videoID: id, methods: [.local]).streams
        let candidates = streams.filter { $0.includesAudioTrack && $0.isNativelyPlayable }.sorted {
            if $0.includesVideoTrack != $1.includesVideoTrack { return !$0.includesVideoTrack }
            return ($0.averageBitrate ?? $0.bitrate ?? 0) > ($1.averageBitrate ?? $1.bitrate ?? 0)
        }
        for stream in candidates.prefix(4) {
            try Task.checkCancellation()
            if try await probe(stream.url) {
                cache[id] = (stream.url, Date()); return stream.url
            }
        }
        throw MusicServiceError.noStream
    }
    private func probe(_ url: URL) async throws -> Bool {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, [200,206].contains(http.statusCode),
              !(http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/html") else { return false }
        var count = 0
        for try await _ in bytes { count += 1; if count >= 1024 { break } }
        return count > 0
    }
}
