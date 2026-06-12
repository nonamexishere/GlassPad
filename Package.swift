// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassPad",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GlassPad",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
