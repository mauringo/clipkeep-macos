import AppKit
import ClipboardCore
import UniformTypeIdentifiers

/// Advertise both native content and a file so editors, upload fields, and Finder
/// can choose the representation they accept. Always export the original text.
enum EntryDragProvider {
    static func make(for entry: ClipboardEntry) -> NSItemProvider {
        let provider: NSItemProvider
        let data: Data
        let type: UTType
        let filename: String
        if let text = entry.text {
            provider = NSItemProvider(object: text as NSString)
            data = Data(text.utf8)
            type = .plainText
            filename = "Clipboard-\(entry.id.uuidString).txt"
        } else {
            provider = NSItemProvider()
            data = entry.imageData ?? Data()
            type = .png
            filename = "Clipboard-\(entry.id.uuidString).png"
            provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
        }
        provider.suggestedName = filename
        // The provider owns this temporary file for the duration of the transfer.
        // Dropping a copy never changes the clipboard or removes a history entry.
        let file = DragFile(data: data, filename: filename)
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier,
                                             fileOptions: [], visibility: .all) { completion in
            do { completion(try file.prepare(), false, nil) }
            catch { completion(nil, false, error) }
            return nil
        }
        return provider
    }
}

private final class DragFile {
    private let data: Data
    private let directory: URL
    private let url: URL

    init(data: Data, filename: String) {
        self.data = data
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardAssistant-Drag-\(UUID().uuidString)", isDirectory: true)
        url = directory.appendingPathComponent(filename)
    }

    func prepare() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        return url
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}
