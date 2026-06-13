import AppKit

// Re-resolves its dynamic background color through updateLayer so the pill
// adapts when the effective appearance flips at runtime; a plain layer-backed
// view would keep the CGColor resolved at init. mouseDownCanMoveWindow stays
// true, so the drag strip is unaffected.
private final class GrabberView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
    }
}

final class NotesPanel: NSPanel {
    private static let noteKey = "note"
    private static let opacityKey = "opacity"
    private static let fontSizeKey = "fontSize"
    private static let defaultOpacity = 0.9
    private static let minOpacity = 0.35
    private static let defaultFontSize = 14.0
    private static let fontSizeRange = 11.0...28.0
    private static let showDuration = 0.15
    private static let hideDuration = 0.12

    private var textView: NSTextView!
    private var opacitySlider: NSSlider!
    private var placeholderLabel: NSTextField!
    private var statsLabel: NSTextField!

    // The fade animations drive alphaValue through 0, so the user's chosen
    // opacity has to live somewhere stable.
    private var opacity = NotesPanel.defaultOpacity
    private var fontSize = NotesPanel.defaultFontSize
    // Distinguishes "fading out" from "visible": toggling mid-fade should
    // bring the panel back rather than hide it a second time.
    private var isHiding = false

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered,
                   defer: false)

        // Float above everything, on every Space, and survive app switches.
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        // .resizable gives a borderless window edge-drag resizing; the frame
        // autosave below persists whatever size the user settles on.
        minSize = NSSize(width: 280, height: 180)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let savedOpacity = UserDefaults.standard.object(forKey: Self.opacityKey) as? Double
        opacity = savedOpacity ?? Self.defaultOpacity
        alphaValue = opacity

        let savedFontSize = UserDefaults.standard.object(forKey: Self.fontSizeKey) as? Double
        fontSize = Self.clampFontSize(savedFontSize ?? Self.defaultFontSize)

        buildContent()
        setFrameAutosaveName("GlassPadPanel")
    }

    // A borderless window refuses key status unless this is overridden.
    override var canBecomeKey: Bool { true }

    func toggle() {
        if isVisible && !isHiding {
            hideAnimated()
        } else {
            showAnimated()
        }
    }

    func saveNote() {
        UserDefaults.standard.set(textView.string, forKey: Self.noteKey)
    }

    override func cancelOperation(_ sender: Any?) {
        toggle()
    }

    private func showAnimated() {
        isHiding = false
        if !setFrameUsingName("GlassPadPanel") {
            center()
        }
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textView)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.showDuration
            animator().alphaValue = opacity
        }
    }

    private func hideAnimated() {
        isHiding = true
        saveNote()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.hideDuration
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Bail out if the panel was re-shown mid-fade.
            guard let self, self.isHiding else { return }
            self.isHiding = false
            self.orderOut(nil)
            self.alphaValue = self.opacity
        })
    }

    @objc func increaseFontSize() {
        applyFontSize(fontSize + 1)
    }

    @objc func decreaseFontSize() {
        applyFontSize(fontSize - 1)
    }

    @objc func resetFontSize() {
        applyFontSize(Self.defaultFontSize)
    }

    private func applyFontSize(_ size: Double) {
        fontSize = Self.clampFontSize(size)
        textView.font = .systemFont(ofSize: fontSize)
        placeholderLabel.font = .systemFont(ofSize: fontSize)
        UserDefaults.standard.set(fontSize, forKey: Self.fontSizeKey)
    }

    private static func clampFontSize(_ size: Double) -> Double {
        min(max(size, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    private func buildContent() {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true

        // A purely decorative grabber pill in the drag strip; GrabberView
        // inherits mouseDownCanMoveWindow == true, so it stays draggable.
        let grabber = GrabberView()
        grabber.wantsLayer = true
        grabber.layer?.cornerRadius = 2.5

        let scrollView = NSTextView.scrollableTextView()
        textView = (scrollView.documentView as! NSTextView)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        // Keep the inset small: padding inside the text view belongs to the
        // NSTextView, which swallows background drags for text selection. The
        // visual breathing room comes from the effect-view margins instead,
        // which stay draggable.
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.delegate = self
        textView.string = UserDefaults.standard.string(forKey: Self.noteKey) ?? ""

        placeholderLabel = NSTextField(labelWithString: "Quick note — saved as you type")
        placeholderLabel.font = .systemFont(ofSize: fontSize)
        placeholderLabel.textColor = .placeholderTextColor

        opacitySlider = NSSlider(value: opacity,
                                 minValue: Self.minOpacity,
                                 maxValue: 1.0,
                                 target: self,
                                 action: #selector(opacityChanged(_:)))
        opacitySlider.controlSize = .mini

        let opacityIcon = NSImageView(image: NSImage(systemSymbolName: "circle.lefthalf.filled",
                                                     accessibilityDescription: "Opacity")!)

        let bottomBar = NSStackView(views: [opacityIcon, opacitySlider])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 6

        statsLabel = NSTextField(labelWithString: "")
        statsLabel.font = .systemFont(ofSize: 10)
        statsLabel.textColor = .secondaryLabelColor
        statsLabel.alignment = .right

        effectView.translatesAutoresizingMaskIntoConstraints = false
        grabber.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(effectView)
        effectView.addSubview(grabber)
        effectView.addSubview(scrollView)
        effectView.addSubview(placeholderLabel)
        effectView.addSubview(bottomBar)
        effectView.addSubview(statsLabel)
        contentView = container

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            grabber.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 8),
            grabber.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),

            // 24pt top strip + 14pt side margins are bare effect view, i.e.
            // real drag handles for isMovableByWindowBackground.
            scrollView.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -14),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -6),

            // 4pt container inset + 5pt default line-fragment padding puts the
            // placeholder right over the first character's origin.
            placeholderLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 6),
            placeholderLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 9),

            bottomBar.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 14),
            bottomBar.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -10),
            opacitySlider.widthAnchor.constraint(equalToConstant: 120),

            statsLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -14),
            statsLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            statsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bottomBar.trailingAnchor, constant: 8),
        ])

        refreshNoteIndicators()
    }

    // Placeholder visibility and the word/character counter both track the
    // note's content.
    private func refreshNoteIndicators() {
        let note = textView.string
        placeholderLabel.isHidden = !note.isEmpty
        let words = note.split(whereSeparator: \.isWhitespace).count
        statsLabel.stringValue = "\(words) words · \(note.count) chars"
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        opacity = sender.doubleValue
        alphaValue = opacity
        UserDefaults.standard.set(opacity, forKey: Self.opacityKey)
    }
}

extension NotesPanel: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        saveNote()
        refreshNoteIndicators()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Esc inside the text view would otherwise trigger autocompletion.
        if commandSelector == #selector(cancelOperation(_:)) {
            toggle()
            return true
        }
        return false
    }
}
