import Foundation
import Testing

@testable import Fixit

@Suite struct DotEnvTests {
    @Test func parsesValuesCommentsAndQuotes() throws {
        let url = try write(
            """
            # comment line
            PLAIN=value
            QUOTED="hello world"
            SINGLE='quoted'
            SPACED =  padded
            EMPTY=
            =missing-key
            no-equals-line
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let parsed = try #require(DotEnv.parse(url: url))
        #expect(parsed["PLAIN"] == "value")
        #expect(parsed["QUOTED"] == "hello world")
        #expect(parsed["SINGLE"] == "quoted")
        #expect(parsed["SPACED"] == "padded")
        #expect(parsed["EMPTY"] == "")
        #expect(parsed.count == 5)
    }

    @Test func missingFileReturnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(DotEnv.parse(url: url) == nil)
    }

    private func write(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).env")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
