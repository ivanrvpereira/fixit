import Foundation
import Testing

@testable import Fixit

@Suite struct SetupDraftTests {
    private static let customConfig = """
        {
          "debugLogging": true,
          "endpoint": "https://proxy.example/v1/chat/completions",
          "model": "my-model",
          "pickerShortcutKey": "p",
          "pickerShortcutModifiers": ["control", "option"],
          "provider": "groq",
          "styles": [
            {"id": "custom-1", "label": "Pirate", "promptFile": "styles/pirate.md", "shortcutKey": "9", "shortcutModifiers": ["option"]}
          ]
        }
        """
    private static let credentials = #"{"groq": "gsk_saved", "openai": "sk-other"}"#

    private func makeConfigDir(config: String? = customConfig, credentials: String? = credentials) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixit-setup-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let config {
            try Data(config.utf8).write(to: dir.appendingPathComponent("config.json"))
        }
        if let credentials {
            try Data(credentials.utf8).write(to: dir.appendingPathComponent("credentials.json"))
        }
        return dir
    }

    private func contents(_ dir: URL, _ name: String) throws -> String {
        try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    @Test func testingUnsavedKeyLeavesConfigAndCredentialsUntouched() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let draft = SetupDraft(configDir: dir, provider: .groq, apiKey: "gsk_typed", env: [:])

        let client = try draft.testClient()

        #expect(client.apiKeyOverride == "gsk_typed")
        #expect(try contents(dir, "config.json") == Self.customConfig)
        #expect(try contents(dir, "credentials.json") == Self.credentials)
    }

    @Test func clearedKeyTestsEnvironmentKeyNotSavedKey() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let withEnv = try SetupDraft(configDir: dir, provider: .groq, apiKey: "  ", env: ["GROQ_API_KEY": "gsk_env"]).testClient()
        let withoutEnv = try SetupDraft(configDir: dir, provider: .groq, apiKey: "", env: [:]).testClient()

        #expect(withEnv.apiKeyOverride == "gsk_env")
        #expect(withoutEnv.apiKeyOverride == "")
    }

    @Test func testingRefusesTypedKeyWhenEnvironmentForcesAnotherProvider() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let draft = SetupDraft(configDir: dir, provider: .groq, apiKey: "gsk_typed", env: ["FIXIT_PROVIDER": "openai"])

        #expect(throws: FixitError.self) { try draft.testClient() }
        #expect(try contents(dir, "config.json") == Self.customConfig)
        #expect(try contents(dir, "credentials.json") == Self.credentials)
    }

    @Test func customProviderIsOfferedOnlyWhenAlreadyConfigured() {
        #expect(SetupDraft.providerChoices(current: .custom).contains(.custom))
        #expect(!SetupDraft.providerChoices(current: .groq).contains(.custom))
    }

    private func savedRuntime(_ dir: URL) throws -> RuntimeConfig {
        let file = try #require(ConfigStore.loadExistingConfig(from: dir))
        return try RuntimeConfig.resolve(file, configDir: dir, env: [:])
    }

    @Test func finishingWithSameProviderKeepsCustomSettings() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("styles"), withIntermediateDirectories: true)
        try Data("Talk like a pirate.".utf8).write(to: dir.appendingPathComponent("styles/pirate.md"))

        try SetupDraft(configDir: dir, provider: .groq, apiKey: "gsk_new", env: [:]).save()

        let runtime = try savedRuntime(dir)
        #expect(runtime.styles.map(\.id) == ["custom-1"])
        #expect(runtime.styles.first?.shortcutKey == "9")
        #expect(runtime.pickerKey == "p")
        #expect(runtime.pickerModifiers == ["control", "option"])
        #expect(runtime.model == "my-model")
        #expect(runtime.baseURL.absoluteString == "https://proxy.example/v1/chat/completions")
        #expect(runtime.debugLogging)
        #expect(try contents(dir, "styles/pirate.md") == "Talk like a pirate.")
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == "gsk_new")
        #expect(CredentialsFile.apiKey(provider: .openAI, configDir: dir) == "sk-other")
    }

    @Test func changingProviderUsesItsDefaultsButKeepsStyles() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let draft = SetupDraft(configDir: dir, provider: .openAI, apiKey: "sk-new", env: [:])

        let tested = try draft.testClient().config
        try draft.save()

        for runtime in [tested, try savedRuntime(dir)] {
            #expect(runtime.provider == .openAI)
            #expect(runtime.model == "gpt-4.1-mini")
            #expect(runtime.baseURL.absoluteString == "https://api.openai.com/v1/chat/completions")
            #expect(runtime.styles.map(\.id) == ["custom-1"])
            #expect(runtime.pickerKey == "p")
        }
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == "gsk_saved")
    }

    @Test func keepingEnvironmentProviderPreservesStoredProviderModelAndEndpoint() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let draft = SetupDraft(configDir: dir, provider: .openAI, apiKey: "sk-typed", env: ["FIXIT_PROVIDER": "openai"])

        let tested = try draft.testClient().config
        try draft.save()

        #expect(tested.model == "my-model")
        #expect(tested.baseURL.absoluteString == "https://proxy.example/v1/chat/completions")
        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.provider == "groq")
        #expect(saved.model == "my-model")
        #expect(saved.endpoint == "https://proxy.example/v1/chat/completions")
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == "gsk_saved")
        #expect(CredentialsFile.apiKey(provider: .openAI, configDir: dir) == "sk-typed")
    }

    @Test func freshSetupWritesUsableDefaults() throws {
        let dir = try makeConfigDir(config: nil, credentials: nil)
        defer { try? FileManager.default.removeItem(at: dir) }

        try SetupDraft(configDir: dir, provider: .groq, apiKey: "gsk_first", env: [:]).save()

        let runtime = try savedRuntime(dir)
        #expect(runtime.styles.map(\.id) == ["native", "proofread", "professional"])
        #expect(runtime.pickerKey == "0")
        #expect(runtime.pickerModifiers == ["command", "shift"])
        #expect(runtime.model == "openai/gpt-oss-120b")
        #expect(runtime.baseURL.absoluteString == "https://api.groq.com/openai/v1/chat/completions")
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == "gsk_first")
    }
}
