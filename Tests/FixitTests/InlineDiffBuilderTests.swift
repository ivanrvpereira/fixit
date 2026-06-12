import AppKit
import Testing

@testable import Fixit

@Suite struct InlineDiffBuilderTests {
    @Test func identicalTextHasNoMarkup() {
        let diff = InlineDiffBuilder.attributedDiff(original: "same text", fixed: "same text", font: font)
        let segments = split(diff)
        #expect(diff.string == "same text")
        #expect(segments.deleted.isEmpty)
        #expect(segments.added.isEmpty)
    }

    @Test func markedSegmentsReconstructBothTexts() {
        let cases: [(original: String, fixed: String)] = [
            ("hello world", "hello there"),
            ("I goes to school", "I go to school"),
            ("", "brand new"),
            ("all gone", ""),
            ("keep  double  spaces", "keep  double  spaces!"),
            ("emoji 🎉 stays", "emoji 🎉 remains"),
        ]
        for (original, fixed) in cases {
            let diff = InlineDiffBuilder.attributedDiff(original: original, fixed: fixed, font: font)
            let segments = split(diff)
            #expect(segments.original == original, "original mismatch for \(original) -> \(fixed)")
            #expect(segments.fixed == fixed, "fixed mismatch for \(original) -> \(fixed)")
        }
    }

    @Test func changedWordIsMarkedDeletedAndAdded() {
        let diff = InlineDiffBuilder.attributedDiff(original: "hello world", fixed: "hello there", font: font)
        let segments = split(diff)
        #expect(segments.deleted == "world")
        #expect(segments.added == "there")
    }

    private let font = NSFont.systemFont(ofSize: 14)

    /// Reassembles the diff: plain + deleted segments must equal the original,
    /// plain + added segments must equal the fixed text.
    private func split(_ diff: NSAttributedString) -> (original: String, fixed: String, deleted: String, added: String) {
        var original = ""
        var fixed = ""
        var deleted = ""
        var added = ""
        diff.enumerateAttributes(in: NSRange(location: 0, length: diff.length)) { attributes, range, _ in
            let token = (diff.string as NSString).substring(with: range)
            if attributes[.strikethroughStyle] != nil {
                original += token
                deleted += token
            } else if attributes[.backgroundColor] != nil {
                fixed += token
                added += token
            } else {
                original += token
                fixed += token
            }
        }
        return (original, fixed, deleted, added)
    }
}
