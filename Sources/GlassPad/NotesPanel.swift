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
    // Legacy single-note key, migrated into the notes array on first run.
    private static let legacyNoteKey = "note"
    // New multi-note storage: an ordered [String] plus the selected index.
    private static let notesKey = "notes"
    private static let currentIndexKey = "currentNoteIndex"
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
    // Compact "‹ 2/5 ›" switcher living in the top strip beside the grabber.
    private var prevNoteButton: NSButton!
    private var nextNoteButton: NSButton!
    private var noteCountLabel: NSTextField!

    // The fade animations drive alphaValue through 0, so the user's chosen
    // opacity has to live somewhere stable.
    private var opacity = NotesPanel.defaultOpacity
    private var fontSize = NotesPanel.defaultFontSize
    // Distinguishes "fading out" from "visible": toggling mid-fade should
    // bring the panel back rather than hide it a second time.
    private var isHiding = false

    // The note collection. `notes` is always non-empty (we keep one empty note
    // rather than allowing zero), and `currentIndex` is always a valid subscript.
    private var notes: [String] = [""]
    private var currentIndex = 0
    // When true the text view shows rendered Markdown (read-only) instead of the
    // raw source. The source itself always lives in `notes[currentIndex]`, so
    // previewing never mutates or loses it.
    private var isPreviewing = false

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

        loadNotes()
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

    // Persists both the array and the selected index. The current note's text
    // is pulled from the text view first, but only when we're editing — in
    // preview mode the text view holds rendered output, not the source.
    func saveNote() {
        if !isPreviewing {
            notes[currentIndex] = textView.string
        }
        UserDefaults.standard.set(notes, forKey: Self.notesKey)
        UserDefaults.standard.set(currentIndex, forKey: Self.currentIndexKey)
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
        // Always return to editing mode while hidden, so re-showing via
        // Option+Space brings the panel back editable rather than stranding the
        // user in read-only preview with no menu to recover the mode.
        if isPreviewing { exitPreview() }
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
        // A larger/smaller body font should also rescale a live preview.
        if isPreviewing {
            renderPreview()
        }
    }

    private static func clampFontSize(_ size: Double) -> Double {
        min(max(size, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    // MARK: - Notes collection

    // Loads the persisted notes, migrating a pre-existing single "note" value
    // into note #1 on first run so nothing the user wrote is lost.
    private func loadNotes() {
        let defaults = UserDefaults.standard
        if let stored = defaults.array(forKey: Self.notesKey) as? [String], !stored.isEmpty {
            notes = stored
        } else if let legacy = defaults.string(forKey: Self.legacyNoteKey) {
            // First launch after the upgrade: adopt the old note as note #1.
            notes = [legacy]
        } else {
            notes = [""]
        }
        let savedIndex = defaults.integer(forKey: Self.currentIndexKey)
        currentIndex = min(max(savedIndex, 0), notes.count - 1)
    }

    // Cmd+1 … Cmd+9 from the main menu. The selector encodes the target index
    // in the menu item's tag (1-based). Indices past the end are a no-op rather
    // than clamping to the last note, so Cmd+5 with three notes does nothing.
    @objc func selectNoteFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag - 1
        guard index >= 0 && index < notes.count else { return }
        switchToNote(index)
    }

    @objc func newNote() {
        // Stash the current note, append a fresh empty one, and jump to it.
        if !isPreviewing { notes[currentIndex] = textView.string }
        // A brand-new note is meant to be written in, so leave preview mode
        // before switching rather than landing read-only on a blank note.
        if isPreviewing { exitPreview() }
        notes.append("")
        switchToNote(notes.count - 1)
    }

    @objc func deleteNote() {
        if notes.count == 1 {
            // Never drop the last note — clear it in place instead.
            notes[0] = ""
            currentIndex = 0
            loadCurrentNote()
            saveNote()
            return
        }
        notes.remove(at: currentIndex)
        // Stay on the same slot if it still exists, otherwise step back.
        switchToNote(min(currentIndex, notes.count - 1), saveOutgoing: false)
    }

    @objc func nextNote() {
        switchToNote((currentIndex + 1) % notes.count)
    }

    @objc func previousNote() {
        switchToNote((currentIndex - 1 + notes.count) % notes.count)
    }

    @objc private func prevNoteClicked() { previousNote() }
    @objc private func nextNoteClicked() { nextNote() }

    // Saves the outgoing note (unless suppressed, e.g. after a delete that
    // already removed it) and loads the incoming one. A live preview re-renders
    // for the new note rather than reverting to editing.
    private func switchToNote(_ index: Int, saveOutgoing: Bool = true) {
        guard !notes.isEmpty else { return }
        let target = min(max(index, 0), notes.count - 1)
        if saveOutgoing && !isPreviewing {
            notes[currentIndex] = textView.string
        }
        currentIndex = target
        loadCurrentNote()
        saveNote()
    }

    // Pushes notes[currentIndex] back into the UI, honouring preview mode.
    private func loadCurrentNote() {
        if isPreviewing {
            renderPreview()
        } else {
            textView.string = notes[currentIndex]
        }
        refreshNoteIndicators()
    }

    // MARK: - Markdown preview

    @objc func togglePreview() {
        if isPreviewing {
            exitPreview()
        } else {
            enterPreview()
        }
    }

    var isInPreview: Bool { isPreviewing }

    private func enterPreview() {
        // Commit the raw source before swapping the text view to read-only.
        notes[currentIndex] = textView.string
        isPreviewing = true
        textView.isEditable = false
        textView.isSelectable = true
        renderPreview()
        refreshNoteIndicators()
    }

    private func exitPreview() {
        isPreviewing = false
        textView.isEditable = true
        textView.isSelectable = true
        // Restore the raw markdown source verbatim; previewing never touched it.
        textView.string = notes[currentIndex]
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        refreshNoteIndicators()
        makeFirstResponder(textView)
    }

    // Renders notes[currentIndex] into the text view's storage. .full parses
    // the complete Markdown grammar (headings, lists, hard line breaks), but it
    // only emits *semantic* intent attributes (NSPresentationIntent /
    // NSInlinePresentationIntent) and strips line breaks — NSTextView does not
    // visually interpret those. So we walk the parsed AttributedString and
    // translate the intents into real fonts, paragraph styles, and reinserted
    // newlines/bullet glyphs that the layout manager actually renders.
    private func renderPreview() {
        let source = notes[currentIndex]
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible)
        let attributed: NSAttributedString
        if let parsed = try? AttributedString(markdown: source, options: options) {
            attributed = styledPreview(from: parsed)
        } else {
            // If parsing fails outright, fall back to the raw text so the
            // preview is never blank.
            attributed = NSAttributedString(
                string: source,
                attributes: [.font: NSFont.systemFont(ofSize: fontSize),
                             .foregroundColor: NSColor.labelColor])
        }
        textView.textStorage?.setAttributedString(attributed)
    }

    // Builds a visually styled NSAttributedString from the parsed Markdown.
    // Foundation groups runs by their block (paragraph/heading/list-item) via
    // NSPresentationIntent; we emit each block as its own line with a font,
    // paragraph style, and (for list items) a bullet/number prefix, and apply
    // bold/italic from the inline intent. labelColor adapts to light/dark and
    // reads legibly on the translucent HUD background.
    private func styledPreview(from source: AttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var lastBlockID: Int?

        for run in source.runs {
            let blockIntent = run.presentationIntent
            // Each top-level block component carries a stable identity; a change
            // means we've moved to a new paragraph/heading/list item and need a
            // separating newline plus a fresh prefix.
            let blockID = blockIntent?.components.first?.identity
            let isNewBlock = blockID != lastBlockID

            if isNewBlock && result.length > 0 {
                result.append(NSAttributedString(string: "\n"))
            }

            // Resolve the block-level styling (heading level, list marker).
            var pointSize = fontSize
            var isHeading = false
            var prefix = ""
            if let components = blockIntent?.components {
                for component in components {
                    switch component.kind {
                    case .header(let level):
                        isHeading = true
                        // h1 largest, tapering toward body size.
                        pointSize = fontSize + max(0, CGFloat(8 - (level - 1) * 2))
                    case .listItem(let ordinal):
                        if isNewBlock {
                            // Distinguish ordered vs unordered by the enclosing list.
                            let ordered = components.contains {
                                if case .orderedList = $0.kind { return true }
                                return false
                            }
                            prefix = ordered ? "\(ordinal). " : "•  "
                        }
                    default:
                        break
                    }
                }
            }

            if isNewBlock && !prefix.isEmpty {
                result.append(NSAttributedString(
                    string: prefix,
                    attributes: [.font: NSFont.systemFont(ofSize: fontSize),
                                 .foregroundColor: NSColor.labelColor]))
            }

            // Inline traits (bold/italic) come through NSInlinePresentationIntent.
            var traits: NSFontDescriptor.SymbolicTraits = []
            if let inline = run.inlinePresentationIntent {
                if inline.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if inline.contains(.emphasized) { traits.insert(.italic) }
            }
            if isHeading { traits.insert(.bold) }

            var font = NSFont.systemFont(ofSize: pointSize)
            if !traits.isEmpty {
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                font = NSFont(descriptor: descriptor, size: pointSize) ?? font
            }

            let text = String(source[run.range].characters)
            result.append(NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: NSColor.labelColor]))

            lastBlockID = blockID
        }

        // Some sources (e.g. plain inline text) carry no block intent; ensure
        // the body still uses the user's font size and a legible color.
        if result.length == 0 {
            return NSAttributedString(
                string: String(source.characters),
                attributes: [.font: NSFont.systemFont(ofSize: fontSize),
                             .foregroundColor: NSColor.labelColor])
        }
        return result
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

        // Compact "‹ 2/5 ›" note switcher. The buttons are borderless and tiny
        // so they sit unobtrusively in the top strip; only the buttons swallow
        // clicks, leaving the rest of the strip a real drag handle.
        prevNoteButton = Self.makeStepperButton("chevron.left",
                                                target: self,
                                                action: #selector(prevNoteClicked))
        nextNoteButton = Self.makeStepperButton("chevron.right",
                                                target: self,
                                                action: #selector(nextNoteClicked))
        noteCountLabel = NSTextField(labelWithString: "1/1")
        noteCountLabel.font = .systemFont(ofSize: 10, weight: .medium)
        noteCountLabel.textColor = .secondaryLabelColor
        noteCountLabel.alignment = .center

        let switcher = NSStackView(views: [prevNoteButton, noteCountLabel, nextNoteButton])
        switcher.orientation = .horizontal
        switcher.spacing = 2
        switcher.alignment = .centerY

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
        textView.string = notes[currentIndex]

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
        switcher.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(effectView)
        effectView.addSubview(grabber)
        effectView.addSubview(switcher)
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

            // The switcher hugs the top-right corner of the strip, vertically
            // centred on the grabber so it shares the 24pt drag-strip band.
            switcher.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -10),
            switcher.centerYAnchor.constraint(equalTo: grabber.centerYAnchor),

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

    // A borderless, image-only stepper button sized to fit the drag strip.
    private static func makeStepperButton(_ symbol: String,
                                          target: AnyObject,
                                          action: Selector) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.target = target
        button.action = action
        button.setButtonType(.momentaryChange)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    // Placeholder visibility, the word/character counter, and the note switcher
    // all track the current note's content and position.
    private func refreshNoteIndicators() {
        let note = notes[currentIndex]
        // Hide the placeholder while previewing (the rendered view stands in
        // for it) and whenever the note has content.
        placeholderLabel.isHidden = !note.isEmpty || isPreviewing
        let words = note.split(whereSeparator: \.isWhitespace).count
        let prefix = isPreviewing ? "preview · " : ""
        statsLabel.stringValue = "\(prefix)\(words) words · \(note.count) chars"

        noteCountLabel.stringValue = "\(currentIndex + 1)/\(notes.count)"
        // Stepping wraps, so the arrows are only disabled when there's a single
        // note to move between.
        let canStep = notes.count > 1
        prevNoteButton.isEnabled = canStep
        nextNoteButton.isEnabled = canStep
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        opacity = sender.doubleValue
        alphaValue = opacity
        UserDefaults.standard.set(opacity, forKey: Self.opacityKey)
    }
}

extension NotesPanel: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        // Editing only happens in edit mode; capture the keystroke into the
        // current note and persist immediately.
        guard !isPreviewing else { return }
        notes[currentIndex] = textView.string
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
