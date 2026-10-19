import AppKit
import SwiftUI
import ClipboardCore

private typealias MenuState<Value> = SwiftUI.State<Value>

/// Transient history and preview attached to the menu-bar icon.
struct MenuBarView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var presentation: PreviewPopover
    let expand: () -> Void
    let showSettings: () -> Void
    let checkForUpdates: () -> Void
    let dismiss: () -> Void
    let quit: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @MenuState private var search = ""
    @MenuState private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    private var entries: [ClipboardEntry] {
        monitor.displayEntries.filter {
            search.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(search)
        }
    }

    private var selected: ClipboardEntry? {
        entries.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard Assistant").font(.headline)
                    Text("\(monitor.entries.count) entries · \(monitor.isMonitoring ? "Capturing" : "Stopped")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { monitor.isMonitoring.toggle() } label: {
                    Label(monitor.isMonitoring ? "Stop" : "Start",
                          systemImage: monitor.isMonitoring ? "stop.fill" : "play.fill")
                }
                .help(monitor.isMonitoring ? "Stop clipboard capture" : "Start clipboard capture")
                Button(action: expand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }.help("Open the full app").accessibilityLabel("Open the full app")
            }.padding(16)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TextField("Search clipboard history", text: $search)
                        .textFieldStyle(.roundedBorder).padding(12).focused($searchFocused)
                    Divider()
                    if entries.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.on.clipboard").font(.largeTitle)
                            Text(monitor.entries.isEmpty ? "Copy text or an image to get started." : "No matching entries")
                                .font(.callout).multilineTextAlignment(.center)
                        }.foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                    } else {
                        ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(entries) { entry in
                                    HStack(spacing: 8) {
                                        VStack(spacing: 10) {
                                            Button { copyAndClose(entry) } label: {
                                                Image(systemName: "doc.on.doc")
                                            }
                                            .help("Copy to clipboard and close")
                                            .accessibilityLabel("Copy to clipboard and close")
                                            Button { monitor.save(entry) } label: {
                                                Image(systemName: "square.and.arrow.down")
                                            }
                                            .help("Save to file…").accessibilityLabel("Save to file")
                                        }
                                        .buttonStyle(.borderless)
                                        Button { selectedID = entry.id } label: {
                                            HistoryRow(entry: entry)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Select to preview")
                                        .accessibilityAddTraits(selectedID == entry.id ? .isSelected : [])
                                        .onDrag { EntryDragProvider.make(for: entry) }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 4)
                                    .background(selectedID == entry.id ? Color.accentColor.opacity(0.14) : Color.clear)
                                    .id(entry.id)
                                    .contextMenu {
                                        Button(entry.isPinned ? "Unpin" : "Pin") { monitor.togglePin(entry) }
                                        Button("Copy") { copyAndClose(entry) }
                                        Button("Save to…") { monitor.save(entry) }
                                    }
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }.onChange(of: selectedID) { id in
                            if let id { proxy.scrollTo(id) }
                        }
                        }
                    }
                }.frame(width: 310)
                Divider()
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
            }
            Divider()
            HStack {
                Button(action: showSettings) { Label("Settings…", systemImage: "gearshape") }
                Spacer()
                Menu {
                    Button("Check for Updates…", action: checkForUpdates)
                    Divider()
                    Button("Quit Clipboard Assistant", action: quit)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }.menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("More options")
            }.padding(14)
        }
        .frame(width: 760, height: 520)
        .scaleEffect(presentation.isClosing && !reduceMotion ? 0.97 : 1, anchor: .top)
        .offset(y: presentation.isClosing && !reduceMotion ? -8 : 0)
        .opacity(presentation.isClosing ? 0 : 1)
        .disabled(presentation.isClosing)
        .onAppear { reconcileSelection() }
        .onChange(of: entries.map(\.id)) { _ in reconcileSelection() }
        .onReceive(presentation.navigation) { navigation in
            switch navigation {
            case .focusSearch: searchFocused = true
            case .activate: if let selected { copyAndClose(selected) }
            case .previous: moveSelection(by: -1)
            case .next: moveSelection(by: 1)
            }
        }
        .onExitCommand(perform: dismiss)
        .alert("Clipboard Assistant", isPresented: Binding(
            get: { monitor.errorMessage != nil },
            set: { if !$0 { monitor.errorMessage = nil } }
        )) {
            Button("OK") { monitor.errorMessage = nil }
        } message: { Text(monitor.errorMessage ?? "") }
    }

    @ViewBuilder
    private var preview: some View {
        if let entry = selected {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.kind == .text ? "Text preview" : "Image preview").font(.headline)
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { monitor.togglePin(entry) } label: {
                        Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    }.help(entry.isPinned ? "Unpin item" : "Keep this item pinned")
                        .accessibilityLabel(entry.isPinned ? "Unpin item" : "Pin item")
                }.padding(16)
                Divider()
                if let text = entry.text {
                    TextPreview(text: text).id(entry.id)
                } else if let data = entry.imageData, let image = NSImage(data: data) {
                    ImageEntryPreview(entry: entry, image: image, monitor: monitor, didCopyText: dismiss)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.on.square").font(.system(size: 32, weight: .light))
                Text("Select an entry to preview").font(.callout)
            }.foregroundStyle(.secondary)
        }
    }

    private func moveSelection(by offset: Int) {
        guard !entries.isEmpty else { return }
        let current = entries.firstIndex { $0.id == selectedID } ?? (offset > 0 ? -1 : entries.count)
        selectedID = entries[min(max(current + offset, 0), entries.count - 1)].id
    }

    private func reconcileSelection() {
        if selected == nil { selectedID = entries.first?.id }
    }

    private func copyAndClose(_ entry: ClipboardEntry) {
        guard !presentation.isClosing else { return }
        monitor.copy(entry)
        dismiss()
    }
}
