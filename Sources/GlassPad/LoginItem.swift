import AppKit
import ServiceManagement

/// Wraps the macOS 13+ login-item API. Only works when running as the bundled
/// .app (SMAppService keys off the bundle identifier); the menu hides the
/// toggle when running the bare SPM binary.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }
}
