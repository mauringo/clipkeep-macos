import AppKit
import ClipboardCore
import UniformTypeIdentifiers

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var isMonitoring = true {
        didSet { lastChangeCount = NSPasteboard.general.changeCount }
    }
    @Published var errorMessage: String?
    private var repository: HistoryRepository?
    private var timer: Timer?
    private var lastChangeCount = -1

    init() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("ClipboardAssistant", isDirectory: true)
            repository = try HistoryRepository(archiveURL: directory.appendingPathComponent("history.json"))
            entries = repository?.entries ?? []
        } catch {
            errorMessage = "Could not load clipboard history. Your existing archive has been preserved. \(error.localizedDescription)"
        }
    }

    func start() {
        guard timer == nil else { return }
        captureClipboard()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureClipboard() }
        }
    }

    private func captureClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard isMonitoring, let repository else { return }

        let entry: ClipboardEntry
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let bitmap = NSBitmapImageRep(data: data),
           let png = bitmap.representation(using: .png, properties: [:]) {
            entry = ClipboardEntry(pngData: png)
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            entry = ClipboardEntry(text: text)
        } else {
            return
        }
        do {
            if try repository.insert(entry) { entries = repository.entries }
        } catch {
            errorMessage = "Could not save clipboard history: \(error.localizedDescription)"
        }
    }

    func copy(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let text = entry.text { pasteboard.setString(text, forType: .string) }
        else if let data = entry.imageData { pasteboard.setData(data, forType: .png) }
        lastChangeCount = pasteboard.changeCount
    }

    func save(_ entry: ClipboardEntry) {
        let panel = NSSavePanel()
        panel.title = "Save clipboard \(entry.kind == .text ? "text" : "image")"
        panel.allowedContentTypes = [entry.kind == .text ? .plainText : .png]
        panel.canCreateDirectories = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        panel.nameFieldStringValue = "Clipboard-\(formatter.string(from: entry.createdAt)).\(entry.kind == .text ? "txt" : "png")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if let text = entry.text { try text.write(to: url, atomically: true, encoding: .utf8) }
            else if let data = entry.imageData { try data.write(to: url, options: .atomic) }
        } catch { errorMessage = "Could not save file: \(error.localizedDescription)" }
    }

    func remove(_ entry: ClipboardEntry) {
        do {
            try repository?.remove(id: entry.id)
            entries = repository?.entries ?? []
        } catch { errorMessage = error.localizedDescription }
    }

    func clear() {
        do {
            try repository?.clear()
            entries = repository?.entries ?? []
        } catch { errorMessage = error.localizedDescription }
    }
}
