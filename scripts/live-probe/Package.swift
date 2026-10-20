// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LiveProbe", platforms: [.macOS(.v13)], dependencies: [
    .package(url: "https://github.com/alexeichhorn/YouTubeKit.git", revision: "e5b7d0396ce12bf3444f0d209e8436c83373b7af")
], targets: [.executableTarget(name: "LiveProbe", dependencies: [.product(name: "YouTubeKit", package: "YouTubeKit")])])
