import Foundation
import CryptoKit

struct CatalogItem: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var artwork: String?
    var track: Track?
    var browseID: String?
    var params: String?
}
struct CatalogShelf: Identifiable, Equatable {
    let id: String
    var title: String
    var items: [CatalogItem]
}
struct CatalogPage {
    var items: [CatalogItem]
    var continuation: String?
}

enum MusicServiceError: LocalizedError {
    case http(Int), invalidResponse, noResults, noStream, unavailable(String)
    var errorDescription: String? {
        switch self {
        case .http(let code): return "Music service returned HTTP \(code). Check your connection and try again."
        case .invalidResponse: return "The music service response could not be read. It may have changed."
        case .noResults: return "No songs were returned by the music service."
        case .noStream: return "No playable audio stream was returned. The provider may require sign-in or restrict this track in your region."
        case .unavailable(let message): return message
        }
    }
}

// Port of the original Android WEB_REMIX catalog protocol. Streaming is resolved
// separately on the device: signed media URLs are never stored in the library.
actor MusicCatalog {
    static let shared = MusicCatalog()
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    private var version: String?
    private var visitor: String?
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        session = URLSession(configuration: config)
    }
    private func configure() async throws {
        guard version == nil else { return }
        var request = URLRequest(url: URL(string: "https://music.youtube.com/")!)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        guard let html = String(data: data, encoding: .utf8),
              let current = Self.capture(#""INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)""#, html) else { throw MusicServiceError.invalidResponse }
        version = current
        visitor = Self.capture(#""VISITOR_DATA"\s*:\s*"([^"]+)""#, html)
    }
    static func capture(_ pattern: String, _ value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value) else { return nil }
        return String(value[range])
    }
    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw MusicServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw MusicServiceError.http(http.statusCode) }
    }
    private func post(_ endpoint: String, _ extras: [String: Any]) async throws -> [String: Any] {
        try await configure()
        var client: [String: Any] = ["clientName": "WEB_REMIX", "clientVersion": version!, "hl": "en", "gl": Locale.current.regionCode ?? "US"]
        if let visitor { client["visitorData"] = visitor }
        var body = extras
        body["context"] = ["client": client, "user": ["lockedSafetyMode": false], "request": ["useSsl": true]]
        var request = URLRequest(url: URL(string: "https://music.youtube.com/youtubei/v1/\(endpoint)?prettyPrint=false")!)
        request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body)
        for (key, value) in ["Content-Type": "application/json", "User-Agent": Self.userAgent, "Origin": "https://music.youtube.com", "Referer": "https://music.youtube.com/", "X-YouTube-Client-Name": "67", "X-YouTube-Client-Version": version!, "Accept-Language": "en-US,en;q=0.9"] { request.setValue(value, forHTTPHeaderField: key) }
        if let visitor { request.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id") }
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        guard data.count < 10_000_000, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], json["error"] == nil else { throw MusicServiceError.invalidResponse }
        if let context = json["responseContext"] as? [String: Any], let value = context["visitorData"] as? String { visitor = value }
        return json
    }
    func search(_ query: String, continuation: String? = nil) async throws -> CatalogPage {
        let body: [String: Any] = continuation.map { ["continuation": $0] } ?? ["query": query, "params": "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"]
        let json = try await post("search", body)
        return CatalogPage(items: CatalogParser.items(json), continuation: CatalogParser.continuation(json))
    }
    func home(explore: Bool = false) async throws -> [CatalogShelf] {
        let json = try await post("browse", ["browseId": explore ? "FEmusic_explore" : "FEmusic_home"])
        return CatalogParser.shelves(json)
    }
    func browse(_ id: String, params: String? = nil, continuation: String? = nil) async throws -> CatalogPage {
        var body: [String: Any] = continuation.map { ["continuation": $0] } ?? ["browseId": id]
        if let params { body["params"] = params }
        let json = try await post("browse", body)
        return CatalogPage(items: CatalogParser.items(json), continuation: CatalogParser.continuation(json))
    }
    func radio(_ videoID: String) async throws -> [Track] {
        let json = try await post("next", ["videoId": videoID, "isAudioOnly": true, "enablePersistentPlaylistPanel": true, "playlistId": "RDAMVM" + videoID])
        return CatalogParser.items(json).compactMap(\.track)
    }
    func lyrics(_ videoID: String) async throws -> String {
        let next = try await post("next", ["videoId": videoID, "isAudioOnly": true])
        let endpoints = CatalogParser.collect(next, key: "browseEndpoint")
        guard let id = endpoints.compactMap({ $0["browseId"] as? String }).first(where: { $0.hasPrefix("MPLY") }) else { return "" }
        let response = try await post("browse", ["browseId": id])
        return CatalogParser.collect(response, key: "musicDescriptionShelfRenderer").map { CatalogParser.text($0["description"]) }.first ?? ""
    }
}

enum CatalogParser {
    static func collect(_ root: Any, key: String) -> [[String: Any]] {
        if let object = root as? [String: Any] {
            var result = (object[key] as? [String: Any]).map { [$0] } ?? []
            // Content arrays preserve the service's shelf/song order.
            for name in object.keys.sorted() { result += collect(object[name]!, key: key) }
            return result
        }
        if let array = root as? [Any] { return array.flatMap { collect($0, key: key) } }
        return []
    }
    static func text(_ node: Any?) -> String {
        guard let node = node as? [String: Any] else { return "" }
        if let simple = node["simpleText"] as? String { return simple }
        return (node["runs"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
    }
    static func at(_ node: Any?, _ path: String...) -> Any? {
        path.reduce(node) { ($0 as? [String: Any])?[$1] }
    }
    static func thumbnail(_ node: Any) -> String? {
        let images = collect(node, key: "thumbnail").flatMap { $0["thumbnails"] as? [[String: Any]] ?? [] }
        return images.max { ($0["width"] as? Int ?? 0) < ($1["width"] as? Int ?? 0) }?["url"] as? String
    }
    static func stableID(_ value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50; bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    static func duration(_ value: String) -> Double {
        let parts = value.split(separator: ":").compactMap { Double($0) }
        guard (2...3).contains(parts.count) else { return 0 }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
    static func item(_ renderer: [String: Any], kind: String) -> CatalogItem? {
        let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
        let title = kind == "musicResponsiveListItemRenderer" ? text(at(columns.first, "musicResponsiveListItemFlexColumnRenderer", "text")) : text(renderer["title"])
        guard !title.isEmpty else { return nil }
        let subtitleNode = kind == "musicResponsiveListItemRenderer" ? at(columns.dropFirst().first, "musicResponsiveListItemFlexColumnRenderer", "text") : (renderer["subtitle"] ?? renderer["longBylineText"] ?? renderer["shortBylineText"])
        let subtitle = text(subtitleNode)
        let nav = renderer["navigationEndpoint"] as? [String: Any] ?? [:]
        let browse = nav["browseEndpoint"] as? [String: Any]
        let browseID = browse?["browseId"] as? String
        let videoID = at(renderer, "playlistItemData", "videoId") as? String
            ?? at(nav, "watchEndpoint", "videoId") as? String
            ?? renderer["videoId"] as? String
            ?? at(renderer, "overlay", "musicItemThumbnailOverlayRenderer", "content", "musicPlayButtonRenderer", "playNavigationEndpoint", "watchEndpoint", "videoId") as? String
        let art = thumbnail(renderer)
        if let id = browseID, !id.hasPrefix("MPED") {
            return CatalogItem(id: id, title: title, subtitle: subtitle, artwork: art, browseID: id, params: browse?["params"] as? String)
        }
        guard let id = videoID ?? browseID.flatMap({ $0.hasPrefix("MPED") ? String($0.dropFirst(4)) : nil }), id.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil else { return nil }
        let parts = subtitle.components(separatedBy: " • ")
        let artist = parts.first { !["song","video","album","single","ep"].contains($0.lowercased()) && duration($0) == 0 } ?? "Unknown artist"
        let endpoints = collect(subtitleNode ?? [:], key: "browseEndpoint")
        let albumID = endpoints.compactMap { $0["browseId"] as? String }.first { $0.hasPrefix("MPRE") }
        let artistID = endpoints.compactMap { $0["browseId"] as? String }.first { $0.hasPrefix("UC") }
        let length = parts.map(duration).first { $0 > 0 } ?? duration(text(renderer["lengthText"]))
        let track = Track(id: stableID("youtube:" + id), title: title, artist: artist, album: "YouTube Music", audioFile: "", duration: length, importedAt: Date(), videoID: id, artworkURL: art, artistBrowseID: artistID, albumBrowseID: albumID)
        return CatalogItem(id: "youtube:" + id, title: title, subtitle: subtitle, artwork: art, track: track)
    }
    static func items(_ root: Any) -> [CatalogItem] {
        var result: [CatalogItem] = [], seen = Set<String>()
        func walk(_ node: Any) {
            if let object = node as? [String: Any] {
                for kind in ["musicResponsiveListItemRenderer","musicTwoRowItemRenderer","playlistPanelVideoRenderer"] {
                    if let renderer = object[kind] as? [String: Any], let entry = item(renderer, kind: kind), seen.insert(entry.id).inserted { result.append(entry); return }
                }
                for key in object.keys.sorted() { walk(object[key]!) }
            } else if let array = node as? [Any] { array.forEach(walk) }
        }
        walk(root); return result
    }
    static func shelves(_ root: Any) -> [CatalogShelf] {
        let renderers = collect(root, key: "musicCarouselShelfRenderer") + collect(root, key: "musicShelfRenderer")
        return renderers.enumerated().compactMap { index, shelf in
            let title = text(at(shelf, "header", "musicCarouselShelfBasicHeaderRenderer", "title"))
            let entries = items(shelf["contents"] ?? [])
            guard !entries.isEmpty else { return nil }
            return CatalogShelf(id: String(index), title: title.isEmpty ? text(shelf["title"]) : title, items: entries)
        }
    }
    static func continuation(_ root: Any) -> String? {
        collect(root, key: "nextContinuationData").first?["continuation"] as? String
            ?? collect(root, key: "continuationCommand").first?["token"] as? String
    }
}
