import AppKit
import Carbon.HIToolbox

// A key chord: a virtual key code plus a Carbon modifier mask (cmdKey/optionKey/
// controlKey/shiftKey). The pair is exactly what RegisterEventHotKey wants and
// what gets persisted to UserDefaults.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    // GlassPad's default: ⌥Space.
    static let `default` = Shortcut(keyCode: UInt32(kVK_Space),
                                    carbonModifiers: UInt32(optionKey))
}

// Persists the chosen chord in UserDefaults. Falls back to the default when
// nothing has been saved, so first launch keeps the historical ⌥Space binding.
enum ShortcutStore {
    private static let keyCodeKey = "hotKeyCode"
    private static let modifiersKey = "hotKeyModifiers"

    static func load(_ defaults: UserDefaults = .standard) -> Shortcut {
        // object(forKey:) distinguishes "absent" from a legitimately stored 0;
        // integer(forKey:) would silently treat a missing key as keyCode 0 (the
        // 'A' key) and quietly change the default.
        guard let code = defaults.object(forKey: keyCodeKey) as? Int,
              let mods = defaults.object(forKey: modifiersKey) as? Int else {
            return .default
        }
        return Shortcut(keyCode: UInt32(truncatingIfNeeded: code),
                        carbonModifiers: UInt32(truncatingIfNeeded: mods))
    }

    static func save(_ shortcut: Shortcut, to defaults: UserDefaults = .standard) {
        defaults.set(Int(shortcut.keyCode), forKey: keyCodeKey)
        defaults.set(Int(shortcut.carbonModifiers), forKey: modifiersKey)
    }
}

// Pure helpers for translating between Cocoa and Carbon modifiers and for
// rendering a chord as a human-readable glyph string. Kept free of UI state so
// they can be unit-tested.
enum ShortcutFormatter {
    // Cocoa flags → Carbon mask. Only the four chord modifiers are considered.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    // The standard menu-ordering of modifier glyphs: ⌃⌥⇧⌘.
    static func modifierString(_ carbonModifiers: UInt32) -> String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result
    }

    // Renders a key code to its display label. Covers the keys a user is likely
    // to bind (letters, digits, space, the common named keys and F1–F20); any
    // other code falls back to "Key (code)" so the recorder never shows blank.
    static func keyString(_ keyCode: UInt32) -> String {
        if let named = namedKeys[Int(keyCode)] { return named }
        return "Key \(keyCode)"
    }

    // The full glyph string, e.g. "⌥Space" or "⌘⇧C".
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        modifierString(modifiers) + keyString(keyCode)
    }

    static func displayString(_ shortcut: Shortcut) -> String {
        displayString(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers)
    }

    // Function keys are allowed without a modifier (they don't collide with
    // ordinary typing the way a bare letter would).
    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeys.contains(Int(keyCode))
    }

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
        kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
        kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    // A lookup keyed by virtual key code. Letters and digits use the ANSI layout
    // positions; this is a display convenience, not a layout-accurate mapping.
    private static let namedKeys: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_Help: "?⃝",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[",
        kVK_ANSI_RightBracket: "]", kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
        kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14",
        kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
        kVK_F19: "F19", kVK_F20: "F20",
    ]
}

// A focusable button-like view that records the next key chord. Click it (or
// tab to it) and it shows "Recording…"; the next chord with at least one
// modifier (or a bare function key) is reported via onChange. A bare key with
// no modifier is rejected so it can't hijack ordinary typing — recording simply
// continues. Esc cancels recording and restores the prior shortcut display.
final class ShortcutRecorderView: NSView {
    // Reports a newly captured chord. Not called when recording is cancelled.
    var onChange: ((Shortcut) -> Void)?

    private var shortcut: Shortcut
    private var isRecording = false
    private let label = NSTextField(labelWithString: "")

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
        ])
        refreshLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 24) }

    // Update the displayed chord from the outside (e.g. after Reset to Default).
    func setShortcut(_ shortcut: Shortcut) {
        self.shortcut = shortcut
        isRecording = false
        refreshLabel()
    }

    // Must accept first responder to capture key events and draw a focus ring.
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { bounds.fill() }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { startRecording() }
        return became
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { cancelRecording() }
        return super.resignFirstResponder()
    }

    private func startRecording() {
        isRecording = true
        label.stringValue = "Recording…"
        label.textColor = .secondaryLabelColor
        needsDisplay = true
    }

    private func cancelRecording() {
        isRecording = false
        refreshLabel()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Esc cancels and restores the previous shortcut.
        if Int(event.keyCode) == kVK_Escape {
            cancelRecording()
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbon = ShortcutFormatter.carbonModifiers(from: flags)
        let keyCode = UInt32(event.keyCode)

        // Require a modifier — except for function keys, which are safe to bind
        // bare. A modifier-less ordinary key is rejected: stay in recording mode
        // so the user can try again rather than capturing a hijacking binding.
        guard carbon != 0 || ShortcutFormatter.isFunctionKey(keyCode) else {
            NSSound.beep()
            return
        }

        shortcut = Shortcut(keyCode: keyCode, carbonModifiers: carbon)
        isRecording = false
        refreshLabel()
        onChange?(shortcut)
        window?.makeFirstResponder(nil)
    }

    private func refreshLabel() {
        label.stringValue = ShortcutFormatter.displayString(shortcut)
        label.textColor = .labelColor
        needsDisplay = true
    }
}
