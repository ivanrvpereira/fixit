import Foundation
import Testing

@testable import Fixit

private func decode(_ json: String) throws -> FixitConfig {
    try JSONDecoder().decode(FixitConfig.self, from: Data(json.utf8))
}

private let tempDir = URL(fileURLWithPath: "/tmp/fixit-unused-config-dir")

@Suite struct RuntimeConfigResolveTests {
    @Test func openRouterBaseURLFromEnvironmentOutranksOnlyTheLegacyOpenRouterBaseURL() throws {
        let env = ["OPENROUTER_BASE_URL": "https://env-openrouter.example/v1/chat/completions"]
        let legacyOnly = try decode(#"{"provider": "openrouter", "openRouterBaseURL": "https://legacy-openrouter.example/v1/chat/completions"}"#)
        let withMapEntry = try decode(#"""
            {"provider": "openrouter", "endpoints": {"openrouter": "https://saved-openrouter.example/v1/chat/completions"}, "openRouterBaseURL": "https://legacy-openrouter.example/v1/chat/completions"}
            """#)

        #expect(try RuntimeConfig.resolve(legacyOnly, configDir: tempDir, env: env).baseURL.absoluteString == "https://env-openrouter.example/v1/chat/completions")
        #expect(try RuntimeConfig.resolve(withMapEntry, configDir: tempDir, env: env).baseURL.absoluteString == "https://saved-openrouter.example/v1/chat/completions")
    }

    @Test func openRouterModelFromEnvironmentOutranksTheSavedMapEntry() throws {
        let config = try decode(#"{"provider": "openrouter", "models": {"openrouter": "saved/model"}}"#)

        let runtime = try RuntimeConfig.resolve(config, configDir: tempDir, env: ["OPENROUTER_MODEL": "env/openrouter-model"])

        #expect(runtime.model == "env/openrouter-model")
    }
}

@Suite struct FixitConfigSavedValuesTests {
    @Test func legacyTopLevelValuesShowOnlyForTheStoredProviderAndOpenRouterKeepsItsLegacyKeys() throws {
        let config = try decode(#"""
            {
              "model": "my-model",
              "endpoint": "https://proxy.example/v1/chat/completions",
              "openRouterModel": "legacy/openrouter-model",
              "openRouterBaseURL": "https://legacy-openrouter.example/v1/chat/completions"
            }
            """#)

        #expect(config.savedModel(for: .groq) == "my-model")
        #expect(config.savedEndpoint(for: .groq) == "https://proxy.example/v1/chat/completions")
        #expect(config.savedModel(for: .openRouter) == "legacy/openrouter-model")
        #expect(config.savedEndpoint(for: .openRouter) == "https://legacy-openrouter.example/v1/chat/completions")
        #expect(config.savedModel(for: .openAI) == nil)
        #expect(config.savedEndpoint(for: .custom) == nil)
    }

    @Test func savedValuesComeFromEachProvidersMapEntry() throws {
        let config = try decode(#"""
            {
              "provider": "groq",
              "models": {"openrouter": "anthropic/claude-sonnet-4", "groq": "llama-3.3-70b-versatile"},
              "endpoints": {"custom": "https://llm.example/v1/chat/completions"}
            }
            """#)

        #expect(config.savedModel(for: .openRouter) == "anthropic/claude-sonnet-4")
        #expect(config.savedModel(for: .groq) == "llama-3.3-70b-versatile")
        #expect(config.savedModel(for: .openAI) == nil)
        #expect(config.savedEndpoint(for: .custom) == "https://llm.example/v1/chat/completions")
        #expect(config.savedEndpoint(for: .groq) == nil)
    }
}

/// Settings' save path: `ConfigStore.save` with the fields Settings shows for the selected provider.
@Suite struct ConfigStoreSaveTests {
    private func makeConfigDir(config: String? = nil) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixit-config-store-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let config {
            try Data(config.utf8).write(to: dir.appendingPathComponent("config.json"))
        }
        return dir
    }

    private func savedFile(_ dir: URL) throws -> FixitConfig {
        try #require(ConfigStore.loadExistingConfig(from: dir))
    }

    private func runtime(_ dir: URL, env: [String: String] = [:]) throws -> RuntimeConfig {
        try RuntimeConfig.resolve(ConfigStore.loadExistingConfig(from: dir) ?? FixitConfig(), configDir: dir, env: env)
    }

    private func save(_ dir: URL, provider: Provider, model: String?, endpoint: String? = nil, env: [String: String] = [:]) throws {
        try ConfigStore.save(
            config: runtime(dir, env: env),
            styles: RuntimeConfig.defaultStyles,
            pickerKey: "0",
            pickerModifiers: ["command", "shift"],
            prompts: [:],
            provider: provider,
            model: model,
            endpoint: endpoint
        )
    }

    @Test func switchingProvidersBackAndForthKeepsEachProvidersModel() throws {
        let dir = try makeConfigDir(config: #"{"provider": "groq"}"#)
        defer { try? FileManager.default.removeItem(at: dir) }

        try save(dir, provider: .openRouter, model: "anthropic/claude-sonnet-4")
        try save(dir, provider: .groq, model: "openai/gpt-oss-120b")

        let shownModel = try savedFile(dir).savedModel(for: .openRouter)
        #expect(shownModel == "anthropic/claude-sonnet-4")

        try save(dir, provider: .openRouter, model: shownModel)

        let back = try runtime(dir)
        #expect(back.provider == .openRouter)
        #expect(back.model == "anthropic/claude-sonnet-4")
        #expect(try savedFile(dir).savedModel(for: .groq) == "openai/gpt-oss-120b")
    }

    @Test func switchingAwayFromCustomAndBackKeepsItsEndpoint() throws {
        let dir = try makeConfigDir(config: #"{"provider": "groq"}"#)
        defer { try? FileManager.default.removeItem(at: dir) }

        try save(dir, provider: .custom, model: "local-model", endpoint: "https://llm.example/v1/chat/completions")
        try save(dir, provider: .groq, model: "openai/gpt-oss-120b")

        let shown = try savedFile(dir)
        #expect(shown.savedEndpoint(for: .custom) == "https://llm.example/v1/chat/completions")
        #expect(shown.savedModel(for: .custom) == "local-model")
        #expect(try runtime(dir).baseURL.absoluteString == "https://api.groq.com/openai/v1/chat/completions")

        try save(dir, provider: .custom, model: shown.savedModel(for: .custom), endpoint: shown.savedEndpoint(for: .custom))

        let back = try runtime(dir)
        #expect(back.provider == .custom)
        #expect(back.baseURL.absoluteString == "https://llm.example/v1/chat/completions")
        #expect(back.model == "local-model")
    }

    @Test func legacyTopLevelModelAndEndpointMoveUnderTheStoredProviderOnSave() throws {
        let dir = try makeConfigDir(config: #"""
            {"provider": "openrouter", "model": "anthropic/claude-sonnet-4", "endpoint": "https://proxy.example/v1/chat/completions"}
            """#)
        defer { try? FileManager.default.removeItem(at: dir) }

        try save(dir, provider: .groq, model: "openai/gpt-oss-120b")

        let saved = try savedFile(dir)
        #expect(saved.model == nil)
        #expect(saved.endpoint == nil)
        #expect(saved.models == ["openrouter": "anthropic/claude-sonnet-4", "groq": "openai/gpt-oss-120b"])
        #expect(saved.endpoints == ["openrouter": "https://proxy.example/v1/chat/completions"])
    }

    @Test func emptyModelFieldRemovesTheProvidersModelSoItsDefaultApplies() throws {
        let dir = try makeConfigDir(config: #"{"provider": "openrouter", "models": {"openrouter": "anthropic/claude-sonnet-4"}}"#)
        defer { try? FileManager.default.removeItem(at: dir) }

        try save(dir, provider: .openRouter, model: nil)

        #expect(try savedFile(dir).savedModel(for: .openRouter) == nil)
        #expect(try runtime(dir).model == "openai/gpt-4.1-mini")
    }

    @Test func openRouterEnvironmentOverridesAreNeverSavedIntoTheMapsOnSettingsSave() throws {
        let dir = try makeConfigDir(config: #"{"provider": "openrouter"}"#)
        defer { try? FileManager.default.removeItem(at: dir) }
        let env = [
            "OPENROUTER_MODEL": "env/openrouter-model",
            "OPENROUTER_BASE_URL": "https://env-openrouter.example/v1/chat/completions",
        ]

        try save(dir, provider: .openRouter, model: nil, env: env)

        let saved = try savedFile(dir)
        #expect(saved.models == nil)
        #expect(saved.endpoints == nil)
        #expect(try runtime(dir).model == "openai/gpt-4.1-mini")
        #expect(try runtime(dir).baseURL.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
    }
}
