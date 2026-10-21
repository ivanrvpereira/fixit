import Foundation
import Testing

@testable import Fixit

@Suite struct AutoFixTargetTests {
    @Test func passwordFieldIsRefused() {
        let target = AutoFixTarget.decide(
            role: "AXTextField", subrole: "AXSecureTextField", valueSettable: true, selectedLength: 0, value: "hunter2", hasInlineImages: false)
        #expect(target == .secure)
    }

    @Test func selectionWinsOverWholeField() {
        let target = AutoFixTarget.decide(
            role: "AXTextArea", subrole: nil, valueSettable: true, selectedLength: 4, value: "some text here", hasInlineImages: false)
        #expect(target == .selection)
    }

    @Test func noSelectionFixesWholeField() {
        let target = AutoFixTarget.decide(
            role: "AXTextField", subrole: nil, valueSettable: true, selectedLength: 0, value: "lets go", hasInlineImages: false)
        #expect(target == .field("lets go"))
    }

    @Test func settableValueCountsAsEditable() {
        let target = AutoFixTarget.decide(
            role: "AXGroup", subrole: nil, valueSettable: true, selectedLength: nil, value: "rich editor text", hasInlineImages: false)
        #expect(target == .field("rich editor text"))
    }

    @Test func nonEditableElementIsRejected() {
        let target = AutoFixTarget.decide(
            role: "AXWebArea", subrole: nil, valueSettable: false, selectedLength: 10, value: nil, hasInlineImages: false)
        #expect(target == .notEditable)
        #expect(AutoFixTarget.decide(role: nil, subrole: nil, valueSettable: false, selectedLength: nil, value: nil, hasInlineImages: false) == .notEditable)
    }

    @Test func editableWithoutReadableValueFallsBack() {
        let target = AutoFixTarget.decide(
            role: "AXTextArea", subrole: nil, valueSettable: false, selectedLength: nil, value: nil, hasInlineImages: false)
        #expect(target == .unknown)
    }

    @Test func inlineImagesFallBackToCopy() {
        // Slack draws emoji as images that its value leaves out; fixing that value would delete them.
        let target = AutoFixTarget.decide(
            role: "AXTextArea", subrole: nil, valueSettable: true, selectedLength: 0, value: "they are going \n", hasInlineImages: true)
        #expect(target == .unknown)
    }

    @Test func emptyFieldIsPassedThrough() {
        let target = AutoFixTarget.decide(
            role: "AXTextField", subrole: nil, valueSettable: true, selectedLength: 0, value: "", hasInlineImages: false)
        #expect(target == .field(""))
    }
}

@Suite struct BlankFieldTests {
    @Test func emptyAndWhitespaceAreBlank() {
        for value in ["", "  ", "\n", " \n\t ", "\u{200B}", "\u{FEFF}\n"] {
            #expect(AutoFixTarget.isBlank(value: value, placeholder: nil, classList: []))
        }
    }

    @Test func placeholderReportedAsValueIsBlank() {
        #expect(AutoFixTarget.isBlank(value: "Message.", placeholder: "Message.", classList: []))
        #expect(AutoFixTarget.isBlank(value: "Message.\n", placeholder: "Message.", classList: []))
    }

    @Test func emptyQuillEditorIsBlank() {
        // Signal's empty composer reads "Message." and exposes no placeholder.
        #expect(AutoFixTarget.isBlank(value: "Message.", placeholder: nil, classList: ["ql-editor", "ql-blank"]))
    }

    @Test func realTextIsNotBlank() {
        #expect(!AutoFixTarget.isBlank(value: "teh meeting", placeholder: "Message.", classList: ["ql-editor"]))
        #expect(!AutoFixTarget.isBlank(value: "Message.", placeholder: nil, classList: []))
    }

    @Test func unreadableValueIsNotBlank() {
        // The copy fallback decides then.
        #expect(!AutoFixTarget.isBlank(value: nil, placeholder: nil, classList: []))
    }
}

@Suite struct OuterWhitespaceTests {
    @Test func restoresTrailingNewline() {
        #expect("Fixed text.".withOuterWhitespace(of: "fixd text\n") == "Fixed text.\n")
    }

    @Test func restoresLeadingSpacesAndTrimsModelPadding() {
        #expect("\n Fixed. \n".withOuterWhitespace(of: "  fixd") == "  Fixed.")
    }

    @Test func leavesTextWithoutOuterWhitespaceAlone() {
        #expect("Fixed.".withOuterWhitespace(of: "fixd") == "Fixed.")
    }
}

@Suite struct ResolveStyleTests {
    private let styles = [
        StyleConfig(id: "proofread", label: "Proofread", promptFile: nil, shortcutKey: nil, shortcutModifiers: nil),
        StyleConfig(id: "native", label: "Sound native", promptFile: nil, shortcutKey: nil, shortcutModifiers: nil),
    ]

    @Test func matchingIDWins() {
        #expect(RuntimeConfig.resolveStyle(id: "proofread", styles: styles).id == "proofread")
    }

    @Test func missingIDFallsBackToNative() {
        #expect(RuntimeConfig.resolveStyle(id: "deleted", styles: styles).id == "native")
        #expect(RuntimeConfig.resolveStyle(id: nil, styles: styles).id == "native")
    }

    @Test func withoutNativeFallsBackToFirstStyle() {
        #expect(RuntimeConfig.resolveStyle(id: nil, styles: [styles[0]]).id == "proofread")
    }
}

@Suite struct CaretMapperTests {
    @Test func endStaysAtEnd() {
        #expect(CaretMapper.map(utf16Offset: 7, from: "lets go", to: "Let's go.") == 9)
    }

    @Test func startStaysAtStart() {
        #expect(CaretMapper.map(utf16Offset: 0, from: "i has a cat", to: "I have a cat.") == 0)
    }

    @Test func followsUnchangedTextAfterAnEarlierFix() {
        // Caret before " cat"; fixing "teh" before it keeps the length.
        #expect(CaretMapper.map(utf16Offset: 3, from: "teh cat sat", to: "the cat sat") == 3)
        // Caret before "is here"; "lets" before it grows by one character.
        #expect(CaretMapper.map(utf16Offset: 9, from: "lets see is here", to: "let's see is here") == 10)
    }

    @Test func caretAfterRewrittenWordLandsAfterTheRewrite() {
        // "i has| a cat" -> "I have| a cat"
        #expect(CaretMapper.map(utf16Offset: 5, from: "i has a cat", to: "I have a cat") == 6)
    }

    @Test func countsEmojiInUTF16() {
        // Caret before " ok"; the emoji is two UTF-16 units and "thx" grows into "thanks".
        #expect(CaretMapper.map(utf16Offset: 6, from: "thx 🎉 ok", to: "thanks 🎉 ok") == 9)
    }
}

@Suite struct AutoFixConfigTests {
    private let configDir = FileManager.default.temporaryDirectory.appendingPathComponent("fixit-tests-\(UUID().uuidString)")

    private var config: RuntimeConfig {
        RuntimeConfig(
            configDir: configDir, debugLogging: false, styles: RuntimeConfig.defaultStyles,
            pickerKey: nil, pickerModifiers: nil, autoFixKey: nil, autoFixModifiers: nil, autoFixStyleID: nil,
            replaceWithoutClipboard: false, provider: .groq, model: "m", baseURL: URL(fileURLWithPath: "/"),
            referer: nil, appTitle: "Fixit", apiKeyEnv: nil)
    }

    private func save(autoFixKey: String? = nil, autoFixStyle: String = "native", replaceWithoutClipboard: Bool = false) throws -> String {
        try ConfigStore.save(
            config: config, styles: RuntimeConfig.defaultStyles, pickerKey: "0", pickerModifiers: ["command", "shift"],
            autoFixKey: autoFixKey, autoFixModifiers: ["command", "shift"], autoFixStyle: autoFixStyle,
            replaceWithoutClipboard: replaceWithoutClipboard, prompts: [:], provider: .groq, model: nil, endpoint: nil)
        return try String(contentsOf: configDir.appendingPathComponent("config.json"), encoding: .utf8)
    }

    @Test func offByDefaultAndPickerKept() throws {
        defer { try? FileManager.default.removeItem(at: configDir) }
        let json = try save()
        #expect(json.contains("pickerShortcutKey"))
        #expect(!json.contains("autoFix"))
        #expect(!json.contains("replaceWithoutClipboard"))
    }

    @Test func savesAutoFixWhenSet() throws {
        defer { try? FileManager.default.removeItem(at: configDir) }
        let saved = try JSONDecoder().decode(FixitConfig.self, from: Data(save(autoFixKey: "9", autoFixStyle: "proofread", replaceWithoutClipboard: true).utf8))
        #expect(saved.autoFixShortcutKey == "9")
        #expect(saved.autoFixShortcutModifiers == ["command", "shift"])
        #expect(saved.autoFixStyle == "proofread")
        #expect(saved.replaceWithoutClipboard == true)
        #expect(saved.pickerShortcutKey == "0")
    }

    @Test func keepsAPickedStyleWithoutAKey() throws {
        defer { try? FileManager.default.removeItem(at: configDir) }
        let saved = try JSONDecoder().decode(FixitConfig.self, from: Data(save(autoFixStyle: "proofread").utf8))
        #expect(saved.autoFixStyle == "proofread")
        #expect(saved.autoFixShortcutKey == nil)
        #expect(saved.autoFixShortcutModifiers == nil)
    }

    @Test func turningExperimentalOptionOffRemovesIt() throws {
        defer { try? FileManager.default.removeItem(at: configDir) }
        #expect(try save(replaceWithoutClipboard: true).contains("replaceWithoutClipboard"))
        #expect(try !save().contains("replaceWithoutClipboard"))
    }

    @Test func checkSetupKeepsAutoFixSettings() throws {
        defer { try? FileManager.default.removeItem(at: configDir) }
        _ = try save(autoFixKey: "9", autoFixStyle: "proofread", replaceWithoutClipboard: true)
        try SetupDraft(configDir: configDir, provider: .groq, apiKey: "", env: [:], saveAPIKey: { _, _, _ in }).save()
        let saved = try #require(ConfigStore.loadExistingConfig(from: configDir))
        #expect(saved.autoFixShortcutKey == "9")
        #expect(saved.autoFixShortcutModifiers == ["command", "shift"])
        #expect(saved.autoFixStyle == "proofread")
        #expect(saved.replaceWithoutClipboard == true)
    }
}

@Suite struct FieldSnapshotTests {
    private let captured = FieldSnapshot(value: "hi there", selection: NSRange(location: 8, length: 0))

    @Test func wholeFieldFixIgnoresAMovedCaret() {
        let now = FieldSnapshot(value: "hi there", selection: NSRange(location: 0, length: 0))
        #expect(now.stillMatches(captured, replacingWholeField: true))
    }

    @Test func wholeFieldFixRefusesChangedText() {
        let now = FieldSnapshot(value: "hi there, more typing", selection: NSRange(location: 21, length: 0))
        #expect(!now.stillMatches(captured, replacingWholeField: true))
    }

    @Test func selectionFixRefusesAMovedSelection() {
        let now = FieldSnapshot(value: "hi there", selection: NSRange(location: 0, length: 2))
        #expect(!now.stillMatches(captured, replacingWholeField: false))
    }

    @Test func selectionFixAcceptsAnUnchangedField() {
        #expect(captured.stillMatches(captured, replacingWholeField: false))
    }
}


@Suite struct CursorPillPlacementTests {
    private let visible = NSRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = NSSize(width: 120, height: 26)

    private func anchor(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, leading: Bool = false) -> CursorPill.Anchor {
        CursorPill.Anchor(rect: NSRect(x: x, y: y, width: width, height: height), leading: leading)
    }

    @Test func centersJustBelowTheCaret() {
        // Caret at x 200; the 120-wide pill starts 60 to its left.
        let origin = CursorPill.origin(for: size, anchor: anchor(x: 200, y: 400, width: 0, height: 18), visible: visible)
        #expect(origin == NSPoint(x: 140, y: 368))
    }

    @Test func flipsAboveNearTheBottomOfTheScreen() {
        let origin = CursorPill.origin(for: size, anchor: anchor(x: 200, y: 10, width: 0, height: 18), visible: visible)
        #expect(origin == NSPoint(x: 140, y: 34))
    }

    @Test func fieldFallbackLinesUpWithTheFieldStart() {
        let origin = CursorPill.origin(for: size, anchor: anchor(x: 300, y: 400, width: 600, height: 40, leading: true), visible: visible)
        #expect(origin == NSPoint(x: 300, y: 368))
    }

    @Test func staysOnScreenAtTheLeftEdge() {
        let origin = CursorPill.origin(for: size, anchor: anchor(x: 10, y: 400, width: 0, height: 18), visible: visible)
        #expect(origin.x == 0)
    }

    @Test func staysOnScreenAtTheRightEdge() {
        let origin = CursorPill.origin(for: size, anchor: anchor(x: 990, y: 400, width: 0, height: 18), visible: visible)
        // Right edge of the screen (1000) minus the pill's width (120).
        #expect(origin.x == 880)
    }
}
