import Testing

@testable import Fixit

@Suite struct SSELineTests {
    @Test func parsesContentDelta() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        #expect(SSELine.parse(line) == .chunk(content: "Hello", cost: nil))
    }

    @Test func parsesUsageCostInFinalChunk() {
        let line = #"data: {"choices":[{"delta":{}}],"usage":{"cost":0.00012}}"#
        #expect(SSELine.parse(line) == .chunk(content: nil, cost: 0.00012))
    }

    @Test func parsesDoneMarker() {
        #expect(SSELine.parse("data: [DONE]") == .done)
    }

    @Test func parsesStreamedError() {
        let line = #"data: {"error":{"message":"rate limited","code":"429"}}"#
        #expect(SSELine.parse(line) == .error("rate limited"))
    }

    @Test func ignoresNonDataLines() {
        #expect(SSELine.parse("") == .ignored)
        #expect(SSELine.parse(": keep-alive comment") == .ignored)
        #expect(SSELine.parse("event: message") == .ignored)
        #expect(SSELine.parse("data: not-json") == .ignored)
    }

    @Test func toleratesLeadingWhitespaceAndNoSpaceAfterColon() {
        let line = #"  data:{"choices":[{"delta":{"content":"x"}}]}"#
        #expect(SSELine.parse(line) == .chunk(content: "x", cost: nil))
    }
}
