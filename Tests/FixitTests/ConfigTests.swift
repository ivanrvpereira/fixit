import Testing

@testable import Fixit

@Suite struct ConfigDirResolutionTests {
    @Test func explicitOverrideWins() {
        let path = RuntimeConfig.resolveConfigDirPath(
            configured: "/custom", defaultPath: "/new", legacyPath: "/old", exists: { _ in true })
        #expect(path == "/custom")
    }

    @Test func freshInstallUsesNewPath() {
        let path = RuntimeConfig.resolveConfigDirPath(
            configured: nil, defaultPath: "/new", legacyPath: "/old", exists: { _ in false })
        #expect(path == "/new")
    }

    @Test func legacyPathUsedOnlyWhenItExists() {
        let path = RuntimeConfig.resolveConfigDirPath(
            configured: nil, defaultPath: "/new", legacyPath: "/old", exists: { $0 == "/old" })
        #expect(path == "/old")
    }

    @Test func newPathPreferredWhenBothExist() {
        let path = RuntimeConfig.resolveConfigDirPath(
            configured: nil, defaultPath: "/new", legacyPath: "/old", exists: { _ in true })
        #expect(path == "/new")
    }
}

@Suite struct StyleIDTests {
    @Test func firstCustomStyleGetsSlotOne() {
        #expect(StyleConfig.uniqueID(existing: ["native", "rewrite"]) == "custom-1")
    }

    @Test func picksFirstFreeSlot() {
        #expect(StyleConfig.uniqueID(existing: ["custom-1", "custom-3"]) == "custom-2")
        #expect(StyleConfig.uniqueID(existing: ["custom-1", "custom-2"]) == "custom-3")
    }
}

@Suite struct ProviderTests {
    @Test func parsesCaseInsensitivelyWithWhitespace() {
        #expect(Provider.from(" OpenRouter ") == .openRouter)
        #expect(Provider.from("GROQ") == .groq)
    }

    @Test func unknownProviderIsNil() {
        #expect(Provider.from("not-a-provider") == nil)
    }

    @Test func everyBuiltInProviderHasAnEndpointAndModel() {
        for provider in Provider.allCases where provider != .custom {
            #expect(provider.defaultEndpoint != nil, "\(provider.rawValue) needs a default endpoint")
            #expect(!provider.defaultModel.isEmpty, "\(provider.rawValue) needs a default model")
        }
    }

    @Test func onlyKeylessProvidersSkipAPIKey() {
        for provider in Provider.allCases {
            let expected = !(provider == .ollama || provider == .custom)
            #expect(provider.requiresAPIKey == expected)
        }
    }
}
