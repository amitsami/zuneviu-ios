import Foundation

struct Track: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var artist: String
    var album: String
    var audioFile: String
    var artworkFile: String?
    var lyricsFile: String?
    var duration: Double
    var importedAt: Date
    var videoID: String?
    var artworkURL: String?
    var artistBrowseID: String?
    var albumBrowseID: String?
    var downloadedAt: Date?
    var saavnID: String?
    var hasOnlineSource: Bool { videoID != nil || saavnID != nil }
    var sourceName: String { saavnID != nil ? "JioSaavn" : "YouTube Music" }
    var isLocal: Bool { !audioFile.isEmpty }
}
struct Playlist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var trackIDs: [UUID] = []
}
struct LibrarySnapshot: Codable {
    var tracks: [Track] = []
    var favorites: Set<UUID> = []
    var playlists: [Playlist] = []
    var history: [UUID] = []
    var listenedSeconds: Double = 0
}
struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}
enum LRCParser {
    static func parse(_ text: String) -> [LyricLine] {
        let expression = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#)
        var lines: [(Double, String)] = []
        for raw in text.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let matches = expression.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }
            let words = ns.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0
                let fractionRange = match.range(at: 3)
                let fraction = fractionRange.location == NSNotFound ? 0 : (Double("0." + ns.substring(with: fractionRange)) ?? 0)
                lines.append((minutes * 60 + seconds + fraction, words))
            }
        }
        return lines.sorted { $0.0 < $1.0 }.enumerated().map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }
}
func clockText(_ seconds: Double) -> String {
    let total = seconds.isFinite ? max(0, Int(seconds)) : 0
    return String(format: "%d:%02d", total / 60, total % 60)
}

// Sorting returns a copy; changing a view never mutates playlist/queue order.
enum TrackOrdering {
    static func sorted(_ tracks: [Track], by order: String, downloads: Bool = false) -> [Track] {
        if order == "original" { return tracks }
        return tracks.enumerated().sorted { lhs, rhs in
            let a = lhs.element, b = rhs.element
            switch order {
            case "title", "titleDescending":
                let comparison = a.title.localizedCaseInsensitiveCompare(b.title)
                if comparison != .orderedSame { return order == "title" ? comparison == .orderedAscending : comparison == .orderedDescending }
            default:
                let first = downloads ? (a.downloadedAt ?? a.importedAt) : a.importedAt
                let second = downloads ? (b.downloadedAt ?? b.importedAt) : b.importedAt
                if first != second { return order == "oldest" ? first < second : first > second }
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
