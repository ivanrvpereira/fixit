import Foundation
import Testing

@testable import Fixit

@Suite struct CredentialsFileTests {
    private func makeTempConfigDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixit-credentials-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func missingFileReadsNil() throws {
        let dir = try makeTempConfigDir()
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == nil)
    }

    @Test func saveThenReadRoundTrips() throws {
        let dir = try makeTempConfigDir()
        try CredentialsFile.saveAPIKey("gsk_test123", provider: .groq, configDir: dir)
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == "gsk_test123")
        #expect(CredentialsFile.apiKey(provider: .openAI, configDir: dir) == nil)
    }

    @Test func savedFileIsOwnerOnly() throws {
        let dir = try makeTempConfigDir()
        try CredentialsFile.saveAPIKey("secret", provider: .groq, configDir: dir)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: CredentialsFile.url(configDir: dir).path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(permissions == 0o600)
    }

    @Test func savingEmptyKeyRemovesOnlyThatEntry() throws {
        let dir = try makeTempConfigDir()
        try CredentialsFile.saveAPIKey("gsk_test123", provider: .groq, configDir: dir)
        try CredentialsFile.saveAPIKey("sk-or-abc", provider: .openRouter, configDir: dir)
        try CredentialsFile.saveAPIKey("   ", provider: .groq, configDir: dir)
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == nil)
        #expect(CredentialsFile.apiKey(provider: .openRouter, configDir: dir) == "sk-or-abc")
    }

    @Test func keysAreTrimmedOnSaveAndRead() throws {
        let dir = try makeTempConfigDir()
        try CredentialsFile.saveAPIKey("  gsk_padded  \n", provider: .groq, configDir: dir)
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == "gsk_padded")
    }

    @Test func fileIsKeyedByProviderID() throws {
        let dir = try makeTempConfigDir()
        try CredentialsFile.saveAPIKey("gsk_test123", provider: .groq, configDir: dir)
        let data = try Data(contentsOf: CredentialsFile.url(configDir: dir))
        let entries = try JSONDecoder().decode([String: String].self, from: data)
        #expect(entries == ["groq": "gsk_test123"])
    }

    @Test func corruptFileReadsNilButSaveRefusesToOverwrite() throws {
        let dir = try makeTempConfigDir()
        try Data("not json".utf8).write(to: CredentialsFile.url(configDir: dir))
        #expect(CredentialsFile.apiKey(provider: .groq, configDir: dir) == nil)
        #expect(throws: (any Error).self) {
            try CredentialsFile.saveAPIKey("gsk_new", provider: .groq, configDir: dir)
        }
        // The corrupt file must be left untouched for the user to inspect.
        let raw = try String(contentsOf: CredentialsFile.url(configDir: dir), encoding: .utf8)
        #expect(raw == "not json")
    }
}
