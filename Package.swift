// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlassPad",
    platforms: [.macOS(.v13)],
    targets: [
        // tools 5.9 ⇒ Swift 5 language mode by default, which keeps strict
        // concurrency as warnings and lets the package build on both Swift
        // 5.10 and 6.x toolchains.
        .executableTarget(name: "GlassPad")
    ]
)
