import Foundation

public struct ClipboardEntry: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, image }
    public let id: UUID
    public let createdAt: Date
    public let kind: Kind
    public let text: String?
    public let imageData: Data?
    public var isPinned: Bool = false
    public var recognizedText: String?

    public var searchableText: String { text ?? recognizedText ?? "Copied image" }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, kind, text, imageData, isPinned, recognizedText
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        kind = try values.decode(Kind.self, forKey: .kind)
        text = try values.decodeIfPresent(String.self, forKey: .text)
        imageData = try values.decodeIfPresent(Data.self, forKey: .imageData)
        isPinned = try values.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        recognizedText = try values.decodeIfPresent(String.self, forKey: .recognizedText)
    }

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
            entries = Self.retained(saved, limit: settings.maximumEntries)
            if saved.count > entries.count { try persist(entries) }
        }
    }

    /// Save/remove the archive before publishing a setting change so failures leave
    /// the previous settings and in-memory history intact.
    public func updateSettings(_ settings: HistorySettings) throws {
        let updated = Self.retained(entries, limit: settings.maximumEntries)
        if settings.keepAfterRestart { try persist(updated) }
        else { try removeArchive() }
        self.settings = settings
        entries = updated
    }

    @discardableResult
    public func insert(_ entry: ClipboardEntry) throws -> Bool {
        guard entries.first.map({ !$0.hasSameContent(as: entry) }) ?? true else { return false }
        let updated = Self.retained([entry] + entries, limit: settings.maximumEntries)
        if settings.keepAfterRestart { try persist(updated) }
        entries = updated
        return true
    }

    /// Pins are exempt from the recent-history limit. Unpinning reapplies that limit.
    public func setPinned(_ pinned: Bool, id: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var updated = entries
        updated[index].isPinned = pinned
        updated = Self.retained(updated, limit: settings.maximumEntries)
        if settings.keepAfterRestart { try persist(updated) }
        entries = updated
    }

    public func setRecognizedText(_ text: String, id: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == id && $0.kind == .image }) else { return }
        var updated = entries
        updated[index].recognizedText = text
        if settings.keepAfterRestart { try persist(updated) }
        entries = updated
    }

    private static func retained(_ entries: [ClipboardEntry], limit: Int) -> [ClipboardEntry] {
        var recentCount = 0
        return entries.filter { entry in
            if entry.isPinned { return true }
            recentCount += 1
            return recentCount <= limit
        }
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
