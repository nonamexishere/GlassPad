import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private let hotKey = HotKeyManager()
    private var panel: NotesPanel!
    // Held so menuNeedsUpdate can retitle it to mirror the panel's mode.
    private var previewItem: NSMenuItem!

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

    // Refresh dynamic menu state each time a menu opens: the Launch at Login
    // checkmark in the status menu, and the preview toggle's title/checkmark in
    // the View menu.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === statusMenu {
            buildStatusMenu()
        } else if menu === previewItem?.menu {
            previewItem.state = panel.isInPreview ? .on : .off
            previewItem.title = panel.isInPreview ? "Edit Markdown Source" : "Toggle Preview"
        }
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
        viewMenu.addItem(.separator())
        // Markdown preview toggle. The title is refreshed in menuNeedsUpdate to
        // reflect the panel's current preview state.
        previewItem = NSMenuItem(title: "Toggle Preview",
                                 action: #selector(NotesPanel.togglePreview),
                                 keyEquivalent: "p")
        previewItem.keyEquivalentModifierMask = [.command, .shift]
        previewItem.target = panel
        viewMenu.addItem(previewItem)

        // Drive the preview item's title/checkmark from menuNeedsUpdate.
        viewMenu.delegate = self

        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu

        // Notes menu: create/delete plus Cmd+1 … Cmd+9 quick-switching. Like
        // the View items these target the panel explicitly, since a
        // non-activating panel never enters the responder chain.
        let notesMenu = NSMenu(title: "Notes")
        let new = NSMenuItem(title: "New Note", action: #selector(NotesPanel.newNote), keyEquivalent: "t")
        new.target = panel
        notesMenu.addItem(new)
        let delete = NSMenuItem(title: "Delete Note", action: #selector(NotesPanel.deleteNote), keyEquivalent: "w")
        delete.target = panel
        notesMenu.addItem(delete)
        notesMenu.addItem(.separator())
        // Nine fixed slots; each carries its 1-based index in the tag so the
        // panel knows which note to select. AppKit ignores equivalents whose
        // target can't act, which is fine when fewer than nine notes exist.
        for n in 1...9 {
            let item = NSMenuItem(title: "Note \(n)",
                                  action: #selector(NotesPanel.selectNoteFromMenu(_:)),
                                  keyEquivalent: "\(n)")
            item.tag = n
            item.target = panel
            notesMenu.addItem(item)
        }

        let notesItem = NSMenuItem()
        notesItem.submenu = notesMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        mainMenu.addItem(viewItem)
        mainMenu.addItem(notesItem)
        NSApp.mainMenu = mainMenu
    }
}
