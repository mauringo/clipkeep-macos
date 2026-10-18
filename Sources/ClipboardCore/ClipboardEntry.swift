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
    public static let capacity = 100
    public private(set) var entries: [ClipboardEntry] = []
    private let archiveURL: URL

    public init(archiveURL: URL) throws {
        self.archiveURL = archiveURL
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            entries = Array(try JSONDecoder().decode([ClipboardEntry].self,
                from: Data(contentsOf: archiveURL)).prefix(Self.capacity))
        }
    }

    @discardableResult
    public func insert(_ entry: ClipboardEntry) throws -> Bool {
        guard entries.first.map({ !$0.hasSameContent(as: entry) }) ?? true else { return false }
        let updated = Array(([entry] + entries).prefix(Self.capacity))
        try persist(updated)
        entries = updated
        return true
    }

    public func remove(id: UUID) throws {
        let updated = entries.filter { $0.id != id }
        try persist(updated)
        entries = updated
    }

    public func clear() throws {
        try persist([])
        entries = []
    }

    private func persist(_ entries: [ClipboardEntry]) throws {
        try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(entries).write(to: archiveURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: archiveURL.path)
    }
}
