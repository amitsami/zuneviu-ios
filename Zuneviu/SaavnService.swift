import Foundation
import CommonCrypto

// Android's optional catalog, ported without the Android IP-spoofing headers.
// Explicit opt-in and separate results: never substitute a different recording
// for a YouTube song. The public format key is not a user's credential or DRM key.
actor SaavnService {
    static let shared = SaavnService()
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 40
        session = URLSession(configuration: config)
    }
    private func request(_ values: [String: String]) async throws -> [String: Any] {
        var components = URLComponents(string: "https://www.jiosaavn.com/api.php")!
        let params = ["_format": "json", "_marker": "0", "api_version": "4", "ctx": "android"].merging(values) { _, new in new }
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Zuneviu-iOS/0.4", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw MusicServiceError.invalidResponse }
        guard response.statusCode == 200 else { throw MusicServiceError.http(response.statusCode) }
        guard data.count <= 2_000_000, let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MusicServiceError.invalidResponse }
        return root
    }
    func search(_ query: String) async throws -> [Track] {
        let root = try await request(["__call": "search.getResults", "q": query, "p": "1", "n": "30"])
        var seen = Set<UUID>()
        return (root["results"] as? [[String: Any]] ?? []).compactMap(Self.track).filter { seen.insert($0.id).inserted }
    }
    func resolve(_ id: String, quality: AudioQuality) async throws -> URL {
        guard id.range(of: #"^[A-Za-z0-9_-]{1,32}$"#, options: .regularExpression) != nil else { throw MusicServiceError.invalidResponse }
        let root = try await request(["__call": "song.getDetails", "pids": id])
        // Android supports both keyed details and a songs envelope. Match exact ID.
        let entries = (root["songs"] as? [[String: Any]]) ?? root.values.compactMap { $0 as? [String: Any] }
        guard let raw = entries.first(where: { $0["id"] as? String == id }),
              let info = raw["more_info"] as? [String: Any], let encrypted = info["encrypted_media_url"] as? String else { throw MusicServiceError.noStream }
        let decrypted = try Self.decrypt(encrypted)
        let supports320 = String(describing: info["320kbps"] ?? "false").lowercased() == "true"
        return try Self.rendition(decrypted, supports320: supports320, quality: quality)
    }
    static func track(_ raw: [String: Any]) -> Track? {
        guard let id = raw["id"] as? String, !id.isEmpty, let title = raw["title"] as? String, !title.isEmpty else { return nil }
        let info = raw["more_info"] as? [String: Any] ?? [:]
        let artists = ((info["artistMap"] as? [String: Any])?["primary_artists"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }.map(decodeText)
        let artwork = (raw["image"] as? String)?.replacingOccurrences(of: "150x150", with: "500x500")
        return Track(id: CatalogParser.stableID("saavn:" + id), title: decodeText(title), artist: artists.isEmpty ? "JioSaavn" : artists.joined(separator: ", "), album: decodeText(info["album"] as? String ?? ""), audioFile: "", duration: Double(String(describing: info["duration"] ?? "0")) ?? 0, importedAt: Date(), artworkURL: artwork?.hasPrefix("https://") == true ? artwork : nil, saavnID: id)
    }
    static func decodeText(_ value: String) -> String {
        var result = value
        for (entity, plain) in [("&quot;", "\""), ("&#039;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] { result = result.replacingOccurrences(of: entity, with: plain) }
        return result
    }
    static func decrypt(_ encoded: String) throws -> String {
        guard let input = Data(base64Encoded: encoded), !input.isEmpty, input.count < 8192 else { throw MusicServiceError.invalidResponse }
        let key = Array("38346591".utf8)
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeDES), written = 0
        let capacity = output.count
        let status = input.withUnsafeBytes { bytes in
            key.withUnsafeBytes { keyBytes in
                CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmDES), CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding), keyBytes.baseAddress, kCCKeySizeDES, nil, bytes.baseAddress, input.count, &output, capacity, &written)
            }
        }
        guard status == kCCSuccess, let result = String(bytes: output.prefix(written), encoding: .utf8) else { throw MusicServiceError.invalidResponse }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func rendition(_ decrypted: String, supports320: Bool, quality: AudioQuality) throws -> URL {
        guard var components = URLComponents(string: decrypted), components.scheme == "https", let host = components.host,
              host == "saavncdn.com" || host.hasSuffix(".saavncdn.com") else { throw MusicServiceError.invalidResponse }
        let expression = try NSRegularExpression(pattern: #"_(48|96|160|320)\.(mp4|aac|mp3)$"#, options: .caseInsensitive)
        let path = components.path as NSString
        if let match = expression.firstMatch(in: components.path, range: NSRange(location: 0, length: path.length)) {
            let offered = Int(path.substring(with: match.range(at: 1))) ?? 96
            let available = supports320 ? [48, 96, 160, 320] : [48, 96].filter { $0 <= offered }
            guard let selected = available.filter({ $0 * 1000 <= quality.ceiling }).max() else { throw MusicServiceError.noStream }
            let suffix = path.substring(with: match.range(at: 2))
            components.path = path.replacingCharacters(in: match.range, with: "_\(selected).\(suffix)")
        } else if quality != .best { throw MusicServiceError.noStream }
        guard let url = components.url else { throw MusicServiceError.invalidResponse }; return url
    }
}

enum AudioSourceResolver {
    static func resolve(_ track: Track, quality: AudioQuality) async throws -> URL {
        if let id = track.saavnID { return try await SaavnService.shared.resolve(id, quality: quality) }
        if let id = track.videoID { return try await StreamResolver.shared.resolve(id, quality: quality) }
        throw MusicServiceError.noStream
    }
}

// Source-specific suggestions retain track identity and are never played as an
// implicit replacement for a selected recording from another provider.
enum SourceRecommendations {
    static func related(_ track: Track) async throws -> [Track] {
        if let id = track.videoID { return try await MusicCatalog.shared.radio(id) }
        if track.saavnID != nil, !track.artist.isEmpty { return try await SaavnService.shared.search(track.artist) }
        return []
    }
}
