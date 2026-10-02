import Foundation
import Testing

@testable import Fixit

@Suite struct LegacyCredentialsMigrationTests {
    private func makeConfigDir(credentials: String?) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixit-migration-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let credentials {
            try Data(credentials.utf8).write(to: credentialsURL(dir))
        }
        return dir
    }

    private func credentialsURL(_ dir: URL) -> URL {
        dir.appendingPathComponent("credentials.json")
    }

    @Test func movesEveryKeyThenDeletesTheFile() throws {
        let dir = try makeConfigDir(credentials: #"{"groq": "gsk_test123", "openrouter": "sk-or-abc"}"#)
        var saved: [Provider: String] = [:]

        LegacyCredentialsMigration.run(configDir: dir) { key, provider in saved[provider] = key }

        #expect(saved == [.groq: "gsk_test123", .openRouter: "sk-or-abc"])
        #expect(!FileManager.default.fileExists(atPath: credentialsURL(dir).path))
    }

    @Test func keepsTheFileWhenASaveFails() throws {
        let dir = try makeConfigDir(credentials: #"{"groq": "gsk_test123"}"#)
        struct KeychainDown: Error {}

        LegacyCredentialsMigration.run(configDir: dir) { _, _ in throw KeychainDown() }

        #expect(FileManager.default.fileExists(atPath: credentialsURL(dir).path))
    }

    @Test func leavesADamagedFileUntouched() throws {
        let dir = try makeConfigDir(credentials: "not json")
        var saveCalls = 0

        LegacyCredentialsMigration.run(configDir: dir) { _, _ in saveCalls += 1 }

        #expect(saveCalls == 0)
        #expect(try String(contentsOf: credentialsURL(dir), encoding: .utf8) == "not json")
    }

    @Test func doesNothingWithoutAFile() throws {
        let dir = try makeConfigDir(credentials: nil)
        var saveCalls = 0

        LegacyCredentialsMigration.run(configDir: dir) { _, _ in saveCalls += 1 }

        #expect(saveCalls == 0)
    }
}
