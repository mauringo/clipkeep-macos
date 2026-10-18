import Foundation
import Testing
@testable import ClipboardCore

struct HistorySettingsTests {
    private func withArchive(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("history.json"))
    }

    @Test func customLimitEvictsOldestAndSurvivesReload() throws {
        try withArchive { url in
            let settings = HistorySettings(maximumEntries: 3)
            let repository = try HistoryRepository(archiveURL: url, settings: settings)
            for index in 0..<5 { try repository.insert(ClipboardEntry(text: "\(index)")) }
            #expect(repository.entries.compactMap(\.text) == ["4", "3", "2"])
            #expect(try HistoryRepository(archiveURL: url, settings: settings).entries == repository.entries)
        }
    }

    @Test func reducingLimitImmediatelyTrimsMemoryAndArchive() throws {
        try withArchive { url in
            let repository = try HistoryRepository(archiveURL: url)
            for index in 0..<5 { try repository.insert(ClipboardEntry(text: "\(index)")) }
            try repository.updateSettings(HistorySettings(maximumEntries: 2))
            #expect(repository.entries.compactMap(\.text) == ["4", "3"])
            #expect(try HistoryRepository(archiveURL: url).entries == repository.entries)
            try repository.updateSettings(HistorySettings(maximumEntries: 10))
            #expect(repository.entries.count == 2)
        }
    }

    @Test func sessionOnlyHistoryNeverWritesAndDoesNotReturnAfterRestart() throws {
        try withArchive { url in
            let settings = HistorySettings(maximumEntries: 2, keepAfterRestart: false)
            let repository = try HistoryRepository(archiveURL: url, settings: settings)
            for index in 0..<3 { try repository.insert(ClipboardEntry(text: "\(index)")) }
            #expect(repository.entries.compactMap(\.text) == ["2", "1"])
            #expect(!FileManager.default.fileExists(atPath: url.path))
            #expect(try HistoryRepository(archiveURL: url, settings: settings).entries.isEmpty)
            try repository.remove(id: repository.entries[0].id)
            try repository.clear()
            #expect(repository.entries.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func disablingRetentionRemovesArchiveButKeepsCurrentEntries() throws {
        try withArchive { url in
            let repository = try HistoryRepository(archiveURL: url)
            try repository.insert(ClipboardEntry(text: "Current session"))
            let original = repository.entries
            try repository.updateSettings(HistorySettings(keepAfterRestart: false))
            #expect(repository.entries == original)
            #expect(!FileManager.default.fileExists(atPath: url.path))
            try repository.updateSettings(HistorySettings(keepAfterRestart: true))
            #expect(try HistoryRepository(archiveURL: url).entries == original)
        }
    }

    @Test func startupWithRetentionOffDiscardsExistingArchive() throws {
        try withArchive { url in
            let repository = try HistoryRepository(archiveURL: url)
            try repository.insert(ClipboardEntry(text: "Old session"))
            let fresh = try HistoryRepository(archiveURL: url,
                settings: HistorySettings(keepAfterRestart: false))
            #expect(fresh.entries.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func lowerLimitOnStartupAlsoTrimsArchive() throws {
        try withArchive { url in
            let repository = try HistoryRepository(archiveURL: url)
            for index in 0..<4 { try repository.insert(ClipboardEntry(text: "\(index)")) }
            let trimmed = try HistoryRepository(archiveURL: url, settings: HistorySettings(maximumEntries: 1))
            #expect(trimmed.entries.compactMap(\.text) == ["3"])
            #expect(try HistoryRepository(archiveURL: url).entries == trimmed.entries)
        }
    }

    @Test func failedSettingsWriteLeavesSessionAndSettingsIntact() throws {
        try withArchive { url in
            // A file cannot be used as the parent directory of an archive.
            try Data().write(to: url)
            let original = HistorySettings(maximumEntries: 5, keepAfterRestart: false)
            let repository = try HistoryRepository(archiveURL: url.appendingPathComponent("blocked.json"), settings: original)
            try repository.insert(ClipboardEntry(text: "Keep me"))
            #expect(throws: (any Error).self) {
                try repository.updateSettings(HistorySettings(maximumEntries: 1))
            }
            #expect(repository.settings == original)
            #expect(repository.entries.compactMap(\.text) == ["Keep me"])
        }
    }

    @Test func limitValidationKeepsSettingsWithinBounds() {
        #expect(HistorySettings().maximumEntries == 100)
        #expect(HistorySettings().keepAfterRestart)
        #expect(HistorySettings(maximumEntries: -5).maximumEntries == 1)
        #expect(HistorySettings(maximumEntries: 5_000).maximumEntries == 1_000)
    }
}
