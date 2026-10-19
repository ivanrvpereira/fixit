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
    /// Records saved keys instead of writing the login Keychain.
    private final class FakeKeyStore {
        var saved: [String] = []
        func save(_ key: String, _ provider: Provider, _: URL) { saved.append("\(provider.rawValue)=\(key)") }
    }

    private func makeDraft(_ dir: URL, _ provider: Provider, key: String, env: [String: String] = [:], store: FakeKeyStore) -> SetupDraft {
        SetupDraft(configDir: dir, provider: provider, apiKey: key, env: env, saveAPIKey: store.save)
    }

    private func makeConfigDir(config: String? = customConfig) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixit-setup-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let config {
            try Data(config.utf8).write(to: dir.appendingPathComponent("config.json"))
        }
        return dir
    }

    private func contents(_ dir: URL, _ name: String) throws -> String {
        try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    @Test func testingUnsavedKeyLeavesConfigAndKeysUntouched() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        let client = try makeDraft(dir, .groq, key: "gsk_typed", store: store).testClient()

        #expect(client.apiKeyOverride == "gsk_typed")
        #expect(try contents(dir, "config.json") == Self.customConfig)
        #expect(store.saved.isEmpty)
    }

    @Test func clearedKeyTestsEnvironmentKeyNotSavedKey() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = FakeKeyStore()

        let withEnv = try makeDraft(dir, .groq, key: "  ", env: ["GROQ_API_KEY": "gsk_env"], store: store).testClient()
        let withoutEnv = try makeDraft(dir, .groq, key: "", store: store).testClient()

        #expect(withEnv.apiKeyOverride == "gsk_env")
        #expect(withoutEnv.apiKeyOverride == "")
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

        let store = FakeKeyStore()

        try makeDraft(dir, .groq, key: "gsk_new", store: store).save()

        let runtime = try savedRuntime(dir)
        #expect(runtime.styles.map(\.id) == ["custom-1"])
        #expect(runtime.styles.first?.shortcutKey == "9")
        #expect(runtime.pickerKey == "p")
        #expect(runtime.pickerModifiers == ["control", "option"])
        #expect(runtime.model == "my-model")
        #expect(runtime.baseURL.absoluteString == "https://proxy.example/v1/chat/completions")
        #expect(runtime.debugLogging)
        #expect(try contents(dir, "styles/pirate.md") == "Talk like a pirate.")
        #expect(store.saved == ["groq=gsk_new"])
    }

    @Test func changingProviderUsesItsDefaultsButKeepsStyles() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()
        let draft = makeDraft(dir, .openAI, key: "sk-new", store: store)

        let tested = try draft.testClient().config
        try draft.save()

        for runtime in [tested, try savedRuntime(dir)] {
            #expect(runtime.provider == .openAI)
            #expect(runtime.model == "gpt-4.1-mini")
            #expect(runtime.baseURL.absoluteString == "https://api.openai.com/v1/chat/completions")
            #expect(runtime.styles.map(\.id) == ["custom-1"])
            #expect(runtime.pickerKey == "p")
        }
        #expect(store.saved == ["openai=sk-new"])
    }

    @Test func freshSetupWritesUsableDefaults() throws {
        let dir = try makeConfigDir(config: nil)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        try makeDraft(dir, .groq, key: "gsk_first", store: store).save()

        let runtime = try savedRuntime(dir)
        #expect(runtime.styles.map(\.id) == ["native", "proofread", "professional"])
        #expect(runtime.pickerKey == "0")
        #expect(runtime.pickerModifiers == ["command", "shift"])
        #expect(runtime.model == "openai/gpt-oss-120b")
        #expect(runtime.baseURL.absoluteString == "https://api.groq.com/openai/v1/chat/completions")
        #expect(store.saved == ["groq=gsk_first"])
    }

    @Test func freshSetupWithNonGroqProviderSavesThatProvider() throws {
        let dir = try makeConfigDir(config: nil)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        try makeDraft(dir, .openAI, key: "sk-first", store: store).save()

        #expect(try savedRuntime(dir).provider == .openAI)
        #expect(store.saved == ["openai=sk-first"])
    }

    @Test(arguments: [
        #"{"provider": "bogus", "model": "my-model", "styles": []}"#,
        #"{"model": "my-model", "styles": []}"#,
    ])
    func unknownOrMissingStoredProviderIsReplacedWhenSwitching(config: String) throws {
        let dir = try makeConfigDir(config: config)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        try makeDraft(dir, .openAI, key: "sk-new", store: store).save()

        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.provider == "openai")
        #expect(saved.model == nil)
        #expect(try savedRuntime(dir).provider == .openAI)
        #expect(try savedRuntime(dir).model == "gpt-4.1-mini")
    }

    @Test func unknownStoredProviderIsReplacedWhenSwitchingToGroq() throws {
        let dir = try makeConfigDir(config: #"{"provider": "bogus", "styles": []}"#)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        try makeDraft(dir, .groq, key: "gsk_new", store: store).save()

        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.provider == "groq")
        #expect(try savedRuntime(dir).provider == .groq)
    }

    @Test func missingStoredProviderCountsAsGroq() throws {
        let dir = try makeConfigDir(config: #"{"model": "my-model", "styles": []}"#)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        try makeDraft(dir, .groq, key: "gsk_new", store: store).save()

        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.provider == nil)
        #expect(saved.model == nil)
        #expect(saved.models == ["groq": "my-model"])
        #expect(try savedRuntime(dir).model == "my-model")
    }

    @Test func changingProviderKeepsEveryProvidersEntriesAndUsesTheNewProvidersSavedModel() throws {
        let dir = try makeConfigDir(config: #"""
            {
              "provider": "groq",
              "models": {"groq": "llama-3.3-70b-versatile", "openrouter": "anthropic/claude-sonnet-4"},
              "endpoints": {"custom": "https://llm.example/v1/chat/completions"},
              "styles": []
            }
            """#)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()
        let draft = makeDraft(dir, .openRouter, key: "sk-or-new", store: store)

        let tested = try draft.testClient().config
        try draft.save()

        for runtime in [tested, try savedRuntime(dir)] {
            #expect(runtime.provider == .openRouter)
            #expect(runtime.model == "anthropic/claude-sonnet-4")
        }
        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.provider == "openrouter")
        #expect(saved.models == ["groq": "llama-3.3-70b-versatile", "openrouter": "anthropic/claude-sonnet-4"])
        #expect(saved.endpoints == ["custom": "https://llm.example/v1/chat/completions"])
    }

    @Test func switchingAwayAndBackKeepsLegacyTopLevelModelAndEndpoint() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()

        try makeDraft(dir, .openAI, key: "sk-new", store: store).save()
        try makeDraft(dir, .groq, key: "gsk_new", store: store).save()

        let runtime = try savedRuntime(dir)
        #expect(runtime.provider == .groq)
        #expect(runtime.model == "my-model")
        #expect(runtime.baseURL.absoluteString == "https://proxy.example/v1/chat/completions")
        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.model == nil)
        #expect(saved.endpoint == nil)
        #expect(saved.models == ["groq": "my-model"])
        #expect(saved.endpoints == ["groq": "https://proxy.example/v1/chat/completions"])
    }

    @Test func openRouterEnvironmentOverridesAreNeverSavedIntoTheMapsOnSetupSave() throws {
        let dir = try makeConfigDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FakeKeyStore()
        let env = [
            "OPENROUTER_MODEL": "env/openrouter-model",
            "OPENROUTER_BASE_URL": "https://env-openrouter.example/v1/chat/completions",
        ]
        let draft = makeDraft(dir, .openRouter, key: "sk-or-new", env: env, store: store)

        #expect(try draft.testClient().config.model == "env/openrouter-model")
        try draft.save()

        let saved = try #require(ConfigStore.loadExistingConfig(from: dir))
        #expect(saved.models == ["groq": "my-model"])
        #expect(saved.endpoints == ["groq": "https://proxy.example/v1/chat/completions"])
        #expect(try savedRuntime(dir).model == "openai/gpt-4.1-mini")
    }
}
