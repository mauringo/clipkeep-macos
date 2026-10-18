import Foundation
import Testing
@testable import ClipboardCore

struct HistoryRepositoryTests {
    private let directory: URL
    private var archive: URL { directory.appendingPathComponent("history.json") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func testKeepsNewest100AcrossRestart() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HistoryRepository(archiveURL: archive)
        for index in 0..<105 { try repository.insert(ClipboardEntry(text: "Entry \(index)")) }
        let reloaded = try HistoryRepository(archiveURL: archive)
        #expect(reloaded.entries.count == 100)
        #expect(reloaded.entries.first?.text == "Entry 104")
        #expect(reloaded.entries.last?.text == "Entry 5")
    }

    @Test func testTextAndImageRoundTripExactly() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HistoryRepository(archiveURL: archive)
        let text = ClipboardEntry(text: "Hello 🌍\n\tSecond line\r\n")
        let image = ClipboardEntry(pngData: Data([137, 80, 78, 71, 0, 255]))
        try repository.insert(text)
        try repository.insert(image)
        #expect(try HistoryRepository(archiveURL: archive).entries == [image, text])
    }

    @Test func testConsecutiveDuplicatesDoNotConsumeHistory() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HistoryRepository(archiveURL: archive)
        #expect(try repository.insert(ClipboardEntry(text: "Same")))
        #expect(try !repository.insert(ClipboardEntry(text: "Same")))
        try repository.insert(ClipboardEntry(text: "Different"))
        #expect(try repository.insert(ClipboardEntry(text: "Same")))
        #expect(repository.entries.count == 3)
    }

    @Test func testRemoveAndClearPersist() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HistoryRepository(archiveURL: archive)
        let entry = ClipboardEntry(text: "Remove me")
        try repository.insert(entry)
        try repository.insert(ClipboardEntry(text: "Keep me"))
        try repository.remove(id: entry.id)
        #expect(try HistoryRepository(archiveURL: archive).entries.map(\.text) == ["Keep me"])
        try repository.clear()
        #expect(try HistoryRepository(archiveURL: archive).entries.isEmpty)
    }

    @Test func testFailedWriteDoesNotChangeHistoryInMemory() throws {
        let parentFile = directory.appendingPathComponent("file")
        try Data().write(to: parentFile)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try HistoryRepository(archiveURL: parentFile.appendingPathComponent("history.json"))
        #expect(throws: (any Error).self) { try repository.insert(ClipboardEntry(text: "Cannot save")) }
        #expect(repository.entries.isEmpty)
    }

    @Test func testCorruptArchiveIsPreserved() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = Data("not valid JSON".utf8)
        try data.write(to: archive)
        #expect(throws: (any Error).self) { try HistoryRepository(archiveURL: archive) }
        #expect(try Data(contentsOf: archive) == data)
    }
}
