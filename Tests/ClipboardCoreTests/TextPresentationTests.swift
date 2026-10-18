import Foundation
import Testing
import Yams
@testable import ClipboardCore

struct TextPresentationTests {
    @Test func formatsNestedJSONWithoutChangingOriginal() throws {
        let original = #"{"name":"🌍","url":"https://example.com/a","nested":{"list":[1,true,null]}}"#
        let result = TextPresentation(original)
        #expect(result.format == .json)
        #expect(result.original == original)
        #expect(result.formatted.contains("\n"))
        #expect(result.formatted.contains("https://example.com/a"))
        let before = try JSONSerialization.jsonObject(with: Data(original.utf8)) as? NSDictionary
        let after = try JSONSerialization.jsonObject(with: Data(result.formatted.utf8)) as? NSDictionary
        #expect(before == after)
    }

    @Test func expandsFlowYAMLAndPreservesQuotedScalars() throws {
        let original = "service: {name: test, replicas: '03', ports: [80, 443]}\n"
        let result = TextPresentation(original)
        #expect(result.format == .yaml)
        #expect(result.original == original)
        #expect(result.formatted.contains("  name: test"))
        #expect(!result.formatted.contains("{name:"))
        #expect(try Yams.compose(yaml: original) == Yams.compose(yaml: result.formatted))
    }

    @Test func supportsMultipleYAMLDocuments() throws {
        let original = "---\na: [1, 2]\n---\nb: {c: 3}\n"
        let result = TextPresentation(original)
        #expect(result.format == .yaml)
        #expect(result.formatted.components(separatedBy: "---").count == 3)
        #expect(result.formatted.contains("  c: 3"))
    }

    @Test func preservesMultilineYAMLAndCommentsInOriginal() throws {
        let original = "# keep this comment\nmessage: |\n  first\n  second\nurl: https://example.com\n"
        let result = TextPresentation(original)
        #expect(result.format == .yaml)
        #expect(result.original == original)
        #expect(try Yams.compose(yaml: original) == Yams.compose(yaml: result.formatted))
    }

    @Test func leavesProseLinksAndInvalidInputUntouched() {
        for original in ["Hello, world!", "https://example.com/a?x=1", "First line\nSecond line",
                         "{broken: [", "service: [invalid", "", "😀 hello", "key: value\nbroken: ["] {
            let result = TextPresentation(original)
            #expect(result.format == .text)
            #expect(result.formatted == original)
        }
    }

    @Test func formatsJSONRootArray() {
        let result = TextPresentation("[1,{\"a\":2}]")
        #expect(result.format == .json)
        #expect(result.formatted.contains("\n"))
    }
}
