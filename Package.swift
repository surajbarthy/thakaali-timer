// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ThakaaliTimer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ThakaaliTimer", path: "Sources/ThakaaliTimer")
    ]
)
