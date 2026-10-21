import Foundation
import ImageIO
@preconcurrency import UIKit
import SwiftUI

// Bounded decoded-image cache, downsampling off the main actor, and in-flight
// coalescing. SwiftUI redraws never synchronously read/decode artwork files.
actor ArtworkLoader {
    static let shared = ArtworkLoader()
    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let session: URLSession
    init() {
        cache.countLimit = 128
        cache.totalCostLimit = 48 * 1024 * 1024
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024, diskPath: "ZuneviuPublicArtwork")
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }
    func image(_ url: URL, pixels: Int = 600) async -> UIImage? {
        let size = max(64, min(1024, pixels))
        let key = url.absoluteString + "|" + String(size)
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value }
        let session = self.session
        let task = Task<UIImage?, Never> {
            do {
                let data: Data
                if url.isFileURL {
                    data = try Data(contentsOf: url, options: .mappedIfSafe)
                } else {
                    guard url.scheme == "https" else { return nil }
                    let (responseData, response) = try await session.data(from: url)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
                    data = responseData
                }
                guard data.count <= 12 * 1024 * 1024,
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: size,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return nil }
                return UIImage(cgImage: cgImage)
            } catch { return nil }
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? size * size * 4
            cache.setObject(image, forKey: key as NSString, cost: cost)
        }
        return image
    }
    func setMemoryBudget(_ mib: Int) { cache.totalCostLimit = max(8, min(128, mib)) * 1024 * 1024 }
    func clear() { cache.removeAllObjects(); session.configuration.urlCache?.removeAllCachedResponses() }
}

struct CachedArtwork: View {
    var url: URL?
    var pixels = 600
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else {
                LinearGradient(colors: [Color(white: 0.15), Color(white: 0.045)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").font(.system(size: 34, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .task(id: (url?.absoluteString ?? "") + "|" + String(pixels)) {
            image = nil
            guard let url else { return }
            let loaded = await ArtworkLoader.shared.image(url, pixels: pixels)
            guard !Task.isCancelled else { return }
            image = loaded
        }
        .accessibilityHidden(true)
    }
}
