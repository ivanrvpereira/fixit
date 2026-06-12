import Testing

@testable import Fixit

@Suite struct ShortcutParserTests {
    @Test func parsesModifiersAndKey() throws {
        let shortcut = try ShortcutParser.parse("cmd+shift+1")
        #expect(shortcut.key == "1")
        #expect(shortcut.modifiers == ["command", "shift"])
    }

    @Test func parsesSymbolModifiers() throws {
        let shortcut = try ShortcutParser.parse("⌘⇧k")
        #expect(shortcut.key == "k")
        #expect(shortcut.modifiers == ["command", "shift"])
    }

    @Test func normalizesModifierOrderAndAliases() throws {
        let shortcut = try ShortcutParser.parse("ctrl+alt+shift+command+9")
        #expect(shortcut.modifiers == ["command", "shift", "option", "control"])
    }

    @Test func emptyInputClearsShortcut() throws {
        let shortcut = try ShortcutParser.parse("  ")
        #expect(shortcut.key == nil)
        #expect(shortcut.modifiers == nil)
    }

    @Test func rejectsUnknownModifier() {
        #expect(throws: FixitError.self) {
            try ShortcutParser.parse("meta+1")
        }
    }

    @Test func rejectsMultiCharacterKey() {
        #expect(throws: FixitError.self) {
            try ShortcutParser.parse("cmd+enter")
        }
    }

    @Test func rejectsTrailingModifier() {
        #expect(throws: FixitError.self) {
            try ShortcutParser.parse("cmd+shift+")
        }
    }

    @Test func displayRoundTripsThroughParse() throws {
        let shortcut = try ShortcutParser.parse("shift+cmd+2")
        let display = ShortcutParser.display(key: shortcut.key, modifiers: shortcut.modifiers)
        #expect(display == "command+shift+2")
        let reparsed = try ShortcutParser.parse(display)
        #expect(reparsed.key == shortcut.key)
        #expect(reparsed.modifiers == shortcut.modifiers)
    }
}
