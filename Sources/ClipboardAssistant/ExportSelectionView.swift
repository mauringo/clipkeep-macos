import AppKit
import SwiftUI
import ClipboardCore

private typealias ExportState<Value> = SwiftUI.State<Value>

struct ExportRequest: Identifiable {
    let id = UUID()
    let entries: [ClipboardEntry]
}

struct ExportSelectionView: View {
    let entries: [ClipboardEntry]
    @Environment(\.dismiss) private var dismiss
    @ExportState private var title = "Clipboard"
    @ExportState private var customTitles: [UUID: String] = [:]
    @ExportState private var isSaving = false
    @ExportState private var errorMessage: String?
    @ExportState private var savedFolder: URL?
    @ExportState private var savedCount = 0
    @ExportState private var showSuccess = false

    private var filenames: [String] {
        BatchExporter.filenames(for: entries, title: title, customTitles: customTitles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save \(entries.count) selected \(entries.count == 1 ? "item" : "items")").font(.title2.bold())
            Text("Give the files a shared title, or name individual items below. Original text and PNG images are saved separately.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("Shared title", text: $title).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Shared export title")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HistoryRow(entry: entry)
                            TextField("Optional title for this item", text: Binding(
                                get: { customTitles[entry.id] ?? "" },
                                set: { customTitles[entry.id] = $0 }
                            )).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Title for item \(index + 1)")
                            Text(filenames[index]).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Divider()
                    }
                }
            }.frame(height: 280)
            Text("Choose a folder next. Existing files are kept; matching names receive a number.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                if isSaving { ProgressView().controlSize(.small); Text("Saving…").font(.callout) }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Choose folder & save…", action: chooseFolder)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 520)
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .alert("Could not save selected items", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        .alert("Saved \(savedCount) \(savedCount == 1 ? "item" : "items")", isPresented: $showSuccess) {
            Button("Show in Finder") {
                if let savedFolder { NSWorkspace.shared.open(savedFolder) }
                dismiss()
            }
            Button("Done") { dismiss() }
        } message: { Text("Your files were saved in \(savedFolder?.lastPathComponent ?? "the selected folder").") }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Save selected clipboard items"
        panel.prompt = "Save here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        // Freeze names and entries while clipboard capture continues in the main app.
        let exportTitle = title
        let itemTitles = customTitles
        let exportEntries = entries
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let files = try await Task.detached(priority: .userInitiated) {
                    try BatchExporter.export(exportEntries, to: directory, title: exportTitle, customTitles: itemTitles)
                }.value
                savedCount = files.count
                savedFolder = directory
                showSuccess = true
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
