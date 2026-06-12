import AppKit

@main
struct GlassPadApp {
    // Kept alive for the lifetime of the process; NSApplication holds its
    // delegate weakly.
    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
