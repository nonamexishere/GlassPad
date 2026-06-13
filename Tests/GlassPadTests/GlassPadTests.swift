import XCTest
import AppKit
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
