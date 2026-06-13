import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private let hotKey = HotKeyManager()
    private var panel: NotesPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The panel comes first: the View menu items target it directly.
        panel = NotesPanel()
        installMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "note.text",
                                           accessibilityDescription: "GlassPad")

        buildStatusMenu()
        statusMenu.delegate = self
        statusItem.menu = statusMenu

        hotKey.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panel.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel.saveNote()
    }

    @objc private func togglePanel() {
        panel.toggle()
    }

    private func buildStatusMenu() {
        statusMenu.removeAllItems()
        let toggle = NSMenuItem(title: "Show / Hide Note", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        statusMenu.addItem(toggle)
        let hint = NSMenuItem(title: "⌥Space  Toggle from anywhere", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        statusMenu.addItem(hint)
        statusMenu.addItem(.separator())
        if Bundle.main.bundleIdentifier != nil {
            let login = NSMenuItem(title: "Launch at Login",
                                   action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            login.state = LoginItem.isEnabled ? .on : .off
            statusMenu.addItem(login)
        }
        statusMenu.addItem(NSMenuItem(title: "Quit GlassPad",
                                      action: #selector(NSApplication.terminate(_:)),
                                      keyEquivalent: "q"))
    }

    // Refresh the Launch at Login checkmark each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        buildStatusMenu()
    }

    @objc private func toggleLoginItem() {
        LoginItem.toggle()
        buildStatusMenu()
    }

    // An .accessory app never shows a main menu, but without one AppKit has
    // nothing to route editing key equivalents through — Cmd+Z/X/C/V/A would
    // all be dead inside the note.
    private func installMainMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = editMenu

        // Same trick for the font-size shortcuts, except these can't rely on
        // the responder chain — a non-activating panel is never in it — so
        // each item targets the panel explicitly.
        let viewMenu = NSMenu(title: "View")
        let bigger = NSMenuItem(title: "Bigger", action: #selector(NotesPanel.increaseFontSize), keyEquivalent: "+")
        bigger.target = panel
        viewMenu.addItem(bigger)
        let smaller = NSMenuItem(title: "Smaller", action: #selector(NotesPanel.decreaseFontSize), keyEquivalent: "-")
        smaller.target = panel
        viewMenu.addItem(smaller)
        let reset = NSMenuItem(title: "Reset Size", action: #selector(NotesPanel.resetFontSize), keyEquivalent: "0")
        reset.target = panel
        viewMenu.addItem(reset)

        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        mainMenu.addItem(viewItem)
        NSApp.mainMenu = mainMenu
    }
}
