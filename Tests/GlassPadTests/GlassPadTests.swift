import XCTest
import AppKit
import Carbon.HIToolbox
@testable import GlassPad

final class NoteMigrationTests: XCTestCase {
    func testStoredArrayWins() {
        XCTAssertEqual(NotesPanel.migratedNotes(stored: ["a", "b"], legacy: "old"), ["a", "b"])
    }

    func testLegacyNoteMigratesIntoFirstSlot() {
        XCTAssertEqual(NotesPanel.migratedNotes(stored: nil, legacy: "old note"), ["old note"])
    }

    func testEmptyStoredArrayFallsBackToLegacy() {
        XCTAssertEqual(NotesPanel.migratedNotes(stored: [], legacy: "old"), ["old"])
    }

    func testNothingStoredGivesOneEmptyNote() {
        XCTAssertEqual(NotesPanel.migratedNotes(stored: nil, legacy: nil), [""])
    }
}

final class MarkdownRenderTests: XCTestCase {
    func testParagraphsAreSeparatedNotJammed() {
        let rendered = NotesPanel.renderMarkdown("First\n\nSecond", bodySize: 14)
        // The old broken renderer produced "FirstSecond"; blocks must be split.
        XCTAssertTrue(rendered.string.contains("First"))
        XCTAssertTrue(rendered.string.contains("Second"))
        XCTAssertFalse(rendered.string.contains("FirstSecond"))
        XCTAssertTrue(rendered.string.contains("\n"))
    }

    func testHeadingIsLargerThanBody() {
        let rendered = NotesPanel.renderMarkdown("# Title", bodySize: 14)
        var maxPointSize: CGFloat = 0
        rendered.enumerateAttribute(.font, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let font = value as? NSFont { maxPointSize = max(maxPointSize, font.pointSize) }
        }
        XCTAssertGreaterThan(maxPointSize, 14)
    }

    func testEveryRunCarriesAFont() {
        // The original bug left runs with no .font at all; ensure that's fixed.
        let rendered = NotesPanel.renderMarkdown("# H\n\nbody **bold**\n\n- item", bodySize: 14)
        var sawFontGap = false
        rendered.enumerateAttribute(.font, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if value == nil { sawFontGap = true }
        }
        XCTAssertFalse(sawFontGap)
    }

    func testBulletPrefixForUnorderedList() {
        let rendered = NotesPanel.renderMarkdown("- a\n- b", bodySize: 14)
        XCTAssertTrue(rendered.string.contains("•"))
    }

    func testBoldRunHasBoldTrait() {
        let rendered = NotesPanel.renderMarkdown("normal **bold**", bodySize: 14)
        var sawBold = false
        rendered.enumerateAttribute(.font, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let font = value as? NSFont,
               font.fontDescriptor.symbolicTraits.contains(.bold) {
                sawBold = true
            }
        }
        XCTAssertTrue(sawBold)
    }
}

final class ShortcutFormatterTests: XCTestCase {
    func testCarbonModifiersFromCocoaFlags() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        XCTAssertEqual(ShortcutFormatter.carbonModifiers(from: flags),
                       UInt32(cmdKey | shiftKey))
        XCTAssertEqual(ShortcutFormatter.carbonModifiers(from: [.option]),
                       UInt32(optionKey))
        XCTAssertEqual(ShortcutFormatter.carbonModifiers(from: []), 0)
    }

    func testModifierGlyphsUseMenuOrdering() {
        // Regardless of insertion order the glyphs come out as ⌃⌥⇧⌘.
        let mods = UInt32(cmdKey | controlKey | optionKey | shiftKey)
        XCTAssertEqual(ShortcutFormatter.modifierString(mods), "⌃⌥⇧⌘")
    }

    func testDisplayStringForDefaultIsOptionSpace() {
        XCTAssertEqual(ShortcutFormatter.displayString(.default), "⌥Space")
    }

    func testDisplayStringForCommandShiftC() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_C),
                                carbonModifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(ShortcutFormatter.displayString(shortcut), "⇧⌘C")
    }

    func testUnknownKeyFallsBackToCode() {
        XCTAssertEqual(ShortcutFormatter.keyString(9999), "Key 9999")
    }

    func testFunctionKeysAreAllowedBare() {
        XCTAssertTrue(ShortcutFormatter.isFunctionKey(UInt32(kVK_F5)))
        XCTAssertFalse(ShortcutFormatter.isFunctionKey(UInt32(kVK_ANSI_A)))
        XCTAssertFalse(ShortcutFormatter.isFunctionKey(UInt32(kVK_Space)))
    }
}

final class ShortcutStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "GlassPadTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testLoadWithoutSavedValueReturnsDefault() {
        XCTAssertEqual(ShortcutStore.load(makeDefaults()), .default)
    }

    func testSaveThenLoadRoundTrips() {
        let defaults = makeDefaults()
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_C),
                                carbonModifiers: UInt32(cmdKey | shiftKey))
        ShortcutStore.save(shortcut, to: defaults)
        XCTAssertEqual(ShortcutStore.load(defaults), shortcut)
    }

    func testKeyCodeZeroIsHonouredNotTreatedAsAbsent() {
        // keyCode 0 ('A') must survive a round-trip rather than reverting to the
        // default, which integer(forKey:) would have done.
        let defaults = makeDefaults()
        let shortcut = Shortcut(keyCode: 0, carbonModifiers: UInt32(cmdKey))
        ShortcutStore.save(shortcut, to: defaults)
        XCTAssertEqual(ShortcutStore.load(defaults), shortcut)
    }
}
