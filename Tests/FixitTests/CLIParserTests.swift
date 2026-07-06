import Testing

@testable import Fixit

@Suite struct CLIParserTests {
    @Test func parsesFixStyleAndText() throws {
        let command = try CLIParser.parse(["fix", "--style", "native", "--text", "hello"])
        #expect(command == .fix(styleID: "native", text: "hello"))
    }

    @Test func parsesFixWithoutTextAsStdinMode() throws {
        let command = try CLIParser.parse(["fix", "--style", "native"])
        #expect(command == .fix(styleID: "native", text: nil))
    }

    @Test func dispatchesMetadataCommands() throws {
        let styles = try CLIParser.parse(["styles"])
        let config = try CLIParser.parse(["config"])
        let version = try CLIParser.parse(["version"])
        let help = try CLIParser.parse(["help"])
        #expect(styles == .styles)
        #expect(config == .config)
        #expect(version == .version)
        #expect(help == .help)
    }

    @Test func parsesTopLevelVersionAndHelpAliases() throws {
        let longVersion = try CLIParser.parse(["--version"])
        let shortVersion = try CLIParser.parse(["-v"])
        let longHelp = try CLIParser.parse(["--help"])
        let shortHelp = try CLIParser.parse(["-h"])
        #expect(longVersion == .version)
        #expect(shortVersion == .version)
        #expect(longHelp == .help)
        #expect(shortHelp == .help)
    }

    @Test func rejectsUnknownSubcommandWithValidList() {
        do {
            _ = try CLIParser.parse(["wat"])
            #expect(Bool(false), "Expected unknown subcommand to throw")
        } catch {
            #expect(error.localizedDescription.contains("Valid subcommands: fix, styles, config, version, help"))
        }
    }

    @Test func mapsLegacyFixArguments() throws {
        let command = try CLIParser.parseLegacy(["--fix", "--style", "native", "--text", "hello"])
        #expect(command == .fix(styleID: "native", text: "hello"))
    }

    @Test func rejectsFlagMissingValue() {
        do {
            _ = try CLIParser.parse(["fix", "--style"])
            #expect(Bool(false), "Expected missing flag value to throw")
        } catch {
            #expect(error.localizedDescription.contains("Missing value for --style"))
        }
    }
}
