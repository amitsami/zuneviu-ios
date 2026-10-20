import Foundation
import AVFoundation
import YouTubeKit

@main struct LiveProbe {
    static func main() async {
        var report: [String: Any] = ["date": ISO8601DateFormatter().string(from: Date()), "extractor": "YouTubeKit e5b7d039", "remoteProxyEnabled": false]
        do {
            // Blender Foundation's public Big Buck Bunny, not a test tone or preview.
            let streams = try await YouTube(videoID: "aqz-KE-bpKQ", methods: [.local]).streams
            let candidates = streams.filter { $0.isNativelyPlayable && $0.includesAudioTrack }.sorted {
                if $0.isAdaptive != $1.isAdaptive { return $0.isAdaptive }
                return ($0.bitrate ?? 0) > ($1.bitrate ?? 0)
            }
            report["streamsFound"] = candidates.count
            guard let stream = candidates.first else { throw NSError(domain: "Probe", code: 1, userInfo: [NSLocalizedDescriptionKey: "No playable stream returned"]) }
            var request = URLRequest(url: stream.url, timeoutInterval: 30)
            request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            report["mediaHTTPStatus"] = status; report["probeBytes"] = data.count
            guard [200,206].contains(status), !data.isEmpty else { throw NSError(domain: "Probe", code: status, userInfo: [NSLocalizedDescriptionKey: "Actual media-byte request failed"]) }
            let asset = AVURLAsset(url: stream.url)
            report["nativePlayable"] = try await asset.load(.isPlayable)
            report["nativeDuration"] = try await asset.load(.duration).seconds
            report["success"] = report["nativePlayable"] as? Bool == true
        } catch {
            report["success"] = false
            // Do not log signed media URLs or authentication material from nested errors.
            report["failureType"] = String(reflecting: type(of: error))
            report["failureCode"] = (error as NSError).code
            let message = String(describing: error)
            report["failureSummary"] = message.contains("http") ? "Extraction or media request failed (URL details redacted)" : String(message.prefix(250))
        }
        let data = try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys])
        try! data.write(to: URL(fileURLWithPath: "live-provider-probe.json"))
        print(String(data: data, encoding: .utf8)!)
        if report["success"] as? Bool != true { exit(1) }
    }
}
