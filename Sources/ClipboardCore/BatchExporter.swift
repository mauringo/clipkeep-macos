import Foundation

public enum BatchExporter {
    /// Export original data in caller order, preserving all existing destination files.
    /// Files are staged before installation; a failed batch removes only its own outputs.
    public static func export(_ entries: [ClipboardEntry], to directory: URL, title: String,
                              customTitles: [UUID: String] = [:]) throws -> [URL] {
        guard !entries.isEmpty else { throw ExportError.emptySelection }
        guard try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw ExportError.notDirectory
        }
        let names = filenames(for: entries, title: title, customTitles: customTitles)
        let payloads: [Data] = try entries.map { entry in
            if entry.kind == .text, let text = entry.text { return Data(text.utf8) }
            if entry.kind == .image, let data = entry.imageData { return data }
            throw ExportError.invalidEntry
        }
        let manager = FileManager.default
        let staging = directory.appendingPathComponent(".ClipboardAssistant-Export-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false,
                                    attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: staging) }
        var installed: [URL] = []
        do {
            for (index, data) in payloads.enumerated() {
                try data.write(to: staging.appendingPathComponent(String(index)), options: .atomic)
            }
            for (index, name) in names.enumerated() {
                let original = directory.appendingPathComponent(name)
                var destination = original
                var suffix = 2
                while true {
                    do {
                        // moveItem fails if the destination exists, including a concurrent export.
                        try manager.moveItem(at: staging.appendingPathComponent(String(index)), to: destination)
                        installed.append(destination)
                        break
                    } catch {
                        guard manager.fileExists(atPath: destination.path) else { throw error }
                        destination = directory.appendingPathComponent(
                            "\(original.deletingPathExtension().lastPathComponent) (\(suffix)).\(original.pathExtension)")
                        suffix += 1
                    }
                }
            }
            return installed
        } catch {
            for url in installed { try? manager.removeItem(at: url) }
            throw error
        }
    }

    public static func filenames(for entries: [ClipboardEntry], title: String,
                                 customTitles: [UUID: String] = [:]) -> [String] {
        let base = safeTitle(title)
        return entries.enumerated().map { index, entry in
            let custom = customTitles[entry.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stem = custom.isEmpty
                ? (entries.count == 1 ? base : "\(base)-\(String(format: "%03d", index + 1))")
                : safeTitle(custom)
            return "\(stem).\(entry.kind == .text ? "txt" : "png")"
        }
    }

    private static func safeTitle(_ title: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:"))
        let cleaned = title.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        var result = ""
        for character in cleaned {
            let next = result + String(character)
            if next.utf8.count > 160 { break }
            result = next
        }
        return result.isEmpty ? "Clipboard" : result
    }

    private enum ExportError: LocalizedError {
        case emptySelection, notDirectory, invalidEntry
        var errorDescription: String? {
            switch self {
            case .emptySelection: return "Select at least one clipboard entry."
            case .notDirectory: return "Choose a folder for the exported files."
            case .invalidEntry: return "One of the selected entries has no original data to export."
            }
        }
    }
}
