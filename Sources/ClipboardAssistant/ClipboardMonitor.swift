import AppKit
import ClipboardCore
import UniformTypeIdentifiers

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var settings: HistorySettings
    @Published var isMonitoring = true {
        didSet { lastChangeCount = NSPasteboard.general.changeCount }
    }
    @Published var errorMessage: String?
    @Published private(set) var capturePreferences = CapturePreferences.load()
    private var recognitionTask: Task<Void, Never>?
    @Published private(set) var recognitionFailures: Set<UUID> = []

    func retryRecognition(_ id: UUID) {
        recognitionFailures.remove(id)
        scheduleRecognition()
    }

    var displayEntries: [ClipboardEntry] {
        entries.filter(\.isPinned) + entries.filter { !$0.isPinned }
    }

    func setCapturePreferences(_ preferences: CapturePreferences) {
        preferences.save()
        capturePreferences = preferences
        if preferences.recognizeTextInImages { scheduleRecognition() }
        else { recognitionTask?.cancel() }
    }

    func togglePin(_ entry: ClipboardEntry) {
        do {
            try repository?.setPinned(!entry.isPinned, id: entry.id)
            entries = repository?.entries ?? []
        } catch { errorMessage = error.localizedDescription }
    }

    func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    private func scheduleRecognition() {
        guard capturePreferences.recognizeTextInImages, recognitionTask == nil else { return }
        recognitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.recognitionTask = nil
                if Task.isCancelled, self.capturePreferences.recognizeTextInImages { self.scheduleRecognition() }
            }
            while !Task.isCancelled, self.capturePreferences.recognizeTextInImages,
                  let entry = self.entries.first(where: {
                      $0.kind == .image && $0.recognizedText == nil && !self.recognitionFailures.contains($0.id)
                  }), let data = entry.imageData {
                do {
                    let text = try await Task.detached(priority: .utility) {
                        try ImageTextRecognition.recognize(data)
                    }.value
                    guard !Task.isCancelled, self.capturePreferences.recognizeTextInImages else { return }
                    try self.repository?.setRecognizedText(text, id: entry.id)
                    self.entries = self.repository?.entries ?? []
                } catch {
                    self.recognitionFailures.insert(entry.id)
                }
            }
        }
    }
    private var repository: HistoryRepository?
    private var timer: Timer?
    private var lastChangeCount = -1

    init() {
        let settings = HistorySettings.load()
        self.settings = settings
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("ClipboardAssistant", isDirectory: true)
            repository = try HistoryRepository(archiveURL: directory.appendingPathComponent("history.json"),
                                               settings: settings)
            entries = repository?.entries ?? []
        } catch {
            errorMessage = "Could not load clipboard history. Your existing archive has been preserved. \(error.localizedDescription)"
        }
    }

    func applySettings(_ settings: HistorySettings) throws {
        guard let repository else { throw CocoaError(.fileReadUnknown) }
        try repository.updateSettings(settings)
        settings.save()
        self.settings = settings
        entries = repository.entries
    }

    func start() {
        guard timer == nil else { return }
        captureClipboard()
        scheduleRecognition()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureClipboard() }
        }
    }

    private func captureClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard isMonitoring, let repository else { return }
        let source = pasteboard.string(forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
        let sourceID = source.flatMap { $0.isEmpty ? nil : $0 } ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard capturePreferences.shouldCapture(types: Set((pasteboard.types ?? []).map(\.rawValue)),
                                               sourceBundleID: sourceID) else { return }

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
            if try repository.insert(entry) { entries = repository.entries; scheduleRecognition() }
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
            try cleanHistory()
        } catch { errorMessage = error.localizedDescription }
    }

    func cleanHistory() throws {
        guard let repository else { throw CocoaError(.fileReadUnknown) }
        try repository.clear()
        entries = repository.entries
    }
}
