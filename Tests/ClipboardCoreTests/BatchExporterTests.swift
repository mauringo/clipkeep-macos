import Foundation
import Testing
@testable import ClipboardCore

struct BatchExporterTests {
    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }

    @Test func exportsMixedOriginalDataWithSharedAndIndividualTitles() throws {
        try withDirectory { directory in
            let original = "{  \"keep\": true }\n  # unchanged\n"
            let png = Data([137, 80, 78, 71, 13, 10, 26, 10])
            let entries = [ClipboardEntry(text: original), ClipboardEntry(pngData: png)]
            let urls = try BatchExporter.export(entries, to: directory, title: "Project notes",
                                                customTitles: [entries[1].id: "Screenshot"])
            #expect(urls.map(\.lastPathComponent) == ["Project notes-001.txt", "Screenshot.png"])
            #expect(try Data(contentsOf: urls[0]) == Data(original.utf8))
            #expect(try Data(contentsOf: urls[1]) == png)
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)
        }
    }

    @Test func duplicateNamesAndRepeatedExportsNeverOverwriteExistingFiles() throws {
        try withDirectory { directory in
            let entries = [ClipboardEntry(text: "first"), ClipboardEntry(text: "second")]
            let titles = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, "Same") })
            let original = directory.appendingPathComponent("Same.txt")
            try Data("existing".utf8).write(to: original)
            let first = try BatchExporter.export(entries, to: directory, title: "Notes", customTitles: titles)
            let second = try BatchExporter.export(entries, to: directory, title: "Notes", customTitles: titles)
            #expect(first.map(\.lastPathComponent) == ["Same (2).txt", "Same (3).txt"])
            #expect(second.map(\.lastPathComponent) == ["Same (4).txt", "Same (5).txt"])
            #expect(try String(contentsOf: original, encoding: .utf8) == "existing")
            #expect(try String(contentsOf: first[0], encoding: .utf8) == "first")
            #expect(try String(contentsOf: first[1], encoding: .utf8) == "second")
        }
    }

    @Test func sanitizesPathComponentsAndBoundsUnicodeFilenameLength() {
        let entry = ClipboardEntry(text: "data")
        let names = BatchExporter.filenames(for: [entry], title: "../../private:name\n")
        #expect(names[0] == "-..-private-name-.txt")
        #expect(!names[0].contains("/"))
        #expect(BatchExporter.filenames(for: [entry], title: " ... ") == ["Clipboard.txt"])
        let longName = BatchExporter.filenames(for: [entry], title: String(repeating: "📋", count: 200))[0]
        #expect(longName.utf8.count <= 164)
    }

    @Test func rejectsEmptySelectionsInvalidEntriesAndNonFoldersWithoutOutput() throws {
        try withDirectory { directory in
            #expect(throws: (any Error).self) { try BatchExporter.export([], to: directory, title: "Empty") }
            let invalid = try JSONDecoder().decode(ClipboardEntry.self,
                from: Data("{\"id\":\"\(UUID().uuidString)\",\"createdAt\":0,\"kind\":\"text\"}".utf8))
            #expect(throws: (any Error).self) {
                try BatchExporter.export([ClipboardEntry(text: "valid"), invalid], to: directory, title: "Notes")
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
            let file = directory.appendingPathComponent("file")
            try Data().write(to: file)
            #expect(throws: (any Error).self) {
                try BatchExporter.export([ClipboardEntry(text: "data")], to: file, title: "Notes")
            }
            #expect(try Data(contentsOf: file).isEmpty)
        }
    }
}
