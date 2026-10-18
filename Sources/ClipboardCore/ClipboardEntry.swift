import Foundation

public struct ClipboardEntry: Identifiable, Codable, Equatable {
    public enum Kind: String, Codable { case text, image }
    public let id: UUID
    public let createdAt: Date
    public let kind: Kind
    public let text: String?
    public let imageData: Data?

    public init(text: String, createdAt: Date = Date()) {
        id = UUID()
        self.createdAt = createdAt
        kind = .text
        self.text = text
        imageData = nil
    }

    /// Image data is normalized to PNG by the clipboard reader.
    public init(pngData: Data, createdAt: Date = Date()) {
        id = UUID()
        self.createdAt = createdAt
        kind = .image
        text = nil
        imageData = pngData
    }

    public func hasSameContent(as other: ClipboardEntry) -> Bool {
        kind == other.kind && text == other.text && imageData == other.imageData
    }
}

/// One atomic archive keeps metadata and image bytes consistent after interruption.
public final class HistoryRepository {
    public private(set) var entries: [ClipboardEntry] = []
    public private(set) var settings: HistorySettings
    private let archiveURL: URL

    public init(archiveURL: URL, settings: HistorySettings = HistorySettings()) throws {
        self.archiveURL = archiveURL
        self.settings = settings
        guard settings.keepAfterRestart else {
            try removeArchive()
            return
        }
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            let saved = try JSONDecoder().decode([ClipboardEntry].self, from: Data(contentsOf: archiveURL))
            entries = Array(saved.prefix(settings.maximumEntries))
            if saved.count > entries.count { try persist(entries) }
        }
    }

    /// Save/remove the archive before publishing a setting change so failures leave
    /// the previous settings and in-memory history intact.
    public func updateSettings(_ settings: HistorySettings) throws {
        let updated = Array(entries.prefix(settings.maximumEntries))
        if settings.keepAfterRestart { try persist(updated) }
        else { try removeArchive() }
        self.settings = settings
        entries = updated
    }

    @discardableResult
    public func insert(_ entry: ClipboardEntry) throws -> Bool {
        guard entries.first.map({ !$0.hasSameContent(as: entry) }) ?? true else { return false }
        let updated = Array(([entry] + entries).prefix(settings.maximumEntries))
        if settings.keepAfterRestart { try persist(updated) }
        entries = updated
        return true
    }

    public func remove(id: UUID) throws {
        let updated = entries.filter { $0.id != id }
        if settings.keepAfterRestart { try persist(updated) }
        entries = updated
    }

    public func clear() throws {
        if settings.keepAfterRestart { try persist([]) }
        entries = []
    }

    private func removeArchive() throws {
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }
    }

    private func persist(_ entries: [ClipboardEntry]) throws {
        try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(entries).write(to: archiveURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: archiveURL.path)
    }
}
