import SwiftUI
import ClipboardCore

// A type alias selects the property wrapper on SDKs that also expose a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct HistoryView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let showSettings: () -> Void
    @ViewState private var selection = EntrySelection()
    @ViewState private var exportRequest: ExportRequest?
    @ViewState private var search = ""
    @ViewState private var filter = EntryFilter.all
    @ViewState private var confirmClear = false
    @ViewState private var copiedID: UUID?

    private enum EntryFilter: String, CaseIterable {
        case all = "All", text = "Text", image = "Images"
    }

    private var filtered: [ClipboardEntry] {
        monitor.displayEntries.filter { entry in
            (filter == .all || (filter == .text && entry.kind == .text) ||
             (filter == .image && entry.kind == .image)) &&
            (search.isEmpty || entry.searchableText.localizedCaseInsensitiveContains(search))
        }
    }

    private var selected: ClipboardEntry? {
        filtered.first(where: { $0.id == selection.previewID })
    }

    private var selectedEntries: [ClipboardEntry] {
        filtered.filter { selection.ids.contains($0.id) }
    }

    private func selectEntry(_ entry: ClipboardEntry) {
        let modifiers = NSEvent.modifierFlags
        selection.select(entry.id, visibleIDs: filtered.map(\.id),
                         toggle: modifiers.contains(.command), range: modifiers.contains(.shift))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "clipboard.fill")
                    .font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Clipboard Assistant").font(.headline)
                    Text("\(monitor.entries.count) entries · \(monitor.entries.filter(\.isPinned).count) pinned · \(monitor.settings.keepAfterRestart ? "Saved on this Mac" : "This session only")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(monitor.isMonitoring ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(monitor.isMonitoring ? "Capturing" : "Paused")
                    .font(.callout).foregroundStyle(.secondary)
                Button { monitor.isMonitoring.toggle() } label: {
                    Image(systemName: monitor.isMonitoring ? "pause.fill" : "play.fill")
                }
                .help(monitor.isMonitoring ? "Pause capture" : "Resume capture")
                .accessibilityLabel(monitor.isMonitoring ? "Pause capture" : "Resume capture")
                Button(action: showSettings) { Image(systemName: "gearshape") }
                    .help("Settings").accessibilityLabel("Settings")
            }
            .padding(20)
            if selectedEntries.count > 1 {
                HStack {
                    Text("\(selectedEntries.count) items selected · Previewing one item")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Save selected…") { exportRequest = ExportRequest(entries: selectedEntries) }
                }.padding(.horizontal, 20).padding(.bottom, 12)
            }
            Divider()
            HSplitView {
                VStack(spacing: 12) {
                    TextField("Search clipboard history", text: $search)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 12).padding(.top, 14)
                    Picker("Show", selection: $filter) {
                        ForEach(EntryFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 12)
                    if filtered.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: search.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                                .font(.system(size: 30)).foregroundStyle(.secondary)
                            Text(monitor.entries.isEmpty ? "Your clipboard starts here" : "No matching entries")
                                .font(.headline)
                            Text(monitor.entries.isEmpty ? "Copy text or an image to add it." : "Try another search or filter.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.multilineTextAlignment(.center).padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(filtered) { entry in
                                HStack(spacing: 8) {
                                    Toggle("Select item", isOn: Binding(
                                        get: { selection.ids.contains(entry.id) },
                                        set: { _ in
                                            selection.select(entry.id, visibleIDs: filtered.map(\.id), toggle: true)
                                        }
                                    ))
                                    .toggleStyle(.checkbox).labelsHidden()
                                    .accessibilityLabel("Select \(entry.text.map { String($0.prefix(40)) } ?? "image")")
                                    Button { selectEntry(entry) } label: {
                                        HistoryRow(entry: entry)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Click to preview. ⌘-click to add an item; Shift-click to select a range.")
                                    Image(systemName: "line.3.horizontal")
                                        .padding(.horizontal, 4).padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                        .onDrag { EntryDragProvider.make(for: entry) }
                                        .help("Drag the original text or image")
                                }
                                .listRowBackground(selection.ids.contains(entry.id)
                                    ? Color.accentColor.opacity(0.18) : Color.clear)
                                .contextMenu {
                                    Button(entry.isPinned ? "Unpin" : "Pin") { monitor.togglePin(entry) }
                                    Button("Copy") { monitor.copy(entry) }
                                    Button("Save to…") { monitor.save(entry) }
                                    if selection.ids.contains(entry.id), selectedEntries.count > 1 {
                                        Button("Save selected…") { exportRequest = ExportRequest(entries: selectedEntries) }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) { monitor.remove(entry) }
                                }
                            }
                        }.listStyle(.sidebar)

                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(selectedEntries.count) selected").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Select all") { selection.selectAll(visibleIDs: filtered.map(\.id)) }
                                .font(.caption).disabled(filtered.isEmpty)
                        }
                        Button {
                            exportRequest = ExportRequest(entries: selectedEntries)
                        } label: {
                            Label("Save selected…", systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).disabled(selectedEntries.isEmpty)
                    }.padding(.horizontal, 14)
                    Divider()
                    HStack {
                        Text("Pinned first · Newest first").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { confirmClear = true } label: {
                            Label("Clean history…", systemImage: "trash")
                        }
                            .buttonStyle(.bordered).font(.caption)
                            .disabled(monitor.entries.isEmpty)
                    }.padding(.horizontal, 14).padding(.bottom, 12)
                }.frame(minWidth: 260, idealWidth: 310, maxWidth: 400)

                VStack(spacing: 0) {
                    if let entry = selected {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.kind == .text ? "Text" : "Image").font(.title2.bold())
                                Text(entry.createdAt.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { monitor.togglePin(entry) } label: {
                                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                            }.help(entry.isPinned ? "Unpin item" : "Keep this item pinned")
                                .accessibilityLabel(entry.isPinned ? "Unpin item" : "Pin item")
                            Label("Drag", systemImage: "hand.draw")
                                .padding(6)
                                .contentShape(Rectangle())
                                .onDrag { EntryDragProvider.make(for: entry) }
                                .help("Drag the original text or image into another app or Finder")
                            Button {
                                monitor.copy(entry)
                                copiedID = entry.id
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    if copiedID == entry.id { copiedID = nil }
                                }
                            } label: {
                                Label(copiedID == entry.id ? "Copied" : "Copy",
                                      systemImage: copiedID == entry.id ? "checkmark" : "doc.on.doc")
                            }
                            Button { monitor.save(entry) } label: {
                                Label("Save to…", systemImage: "square.and.arrow.down")
                            }.buttonStyle(.borderedProminent)
                        }.padding(24)
                        Divider()
                        if let text = entry.text {
                            TextPreview(text: text).id(entry.id)
                        } else if let data = entry.imageData, let image = NSImage(data: data) {
                            ImageEntryPreview(entry: entry, image: image, monitor: monitor)
                        }
                    } else {
                        Spacer()
                        Image(systemName: "square.on.square").font(.system(size: 44, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("Select an entry to preview").font(.title3).padding(.top, 14)
                        Text("Copy it again or save it to a file.")
                            .foregroundStyle(.secondary).padding(.top, 4)
                        Spacer()
                    }
                }.frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(minWidth: 780, minHeight: 500)
        .onAppear {
            if selection.ids.isEmpty, let first = filtered.first {
                selection.select(first.id, visibleIDs: filtered.map(\.id))
            }
        }
        .onChange(of: filtered.map(\.id)) { ids in
            selection.reconcile(visibleIDs: ids)
        }
        .sheet(item: $exportRequest) { request in
            ExportSelectionView(entries: request.entries)
        }
        .alert("Clean clipboard history?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clean history", role: .destructive) { monitor.clear() }
        } message: {
            Text("This deletes all saved entries from this app. The current system clipboard stays available.")
        }
        .alert("Clipboard Assistant", isPresented: Binding(
            get: { monitor.errorMessage != nil },
            set: { if !$0 { monitor.errorMessage = nil } }
        )) {
            Button("OK") { monitor.errorMessage = nil }
        } message: { Text(monitor.errorMessage ?? "") }
    }
}

struct HistoryRow: View {
    let entry: ClipboardEntry
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let data = entry.imageData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit()
                    .frame(width: 38, height: 38)
                    .background(Color.secondary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "text.alignleft").foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 5))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.text.map { String($0.prefix(300)).replacingOccurrences(of: "\n", with: " ") } ?? "Copied image")
                    .lineLimit(2).font(.system(size: 13, weight: .medium))
                HStack(spacing: 4) {
                    if entry.isPinned { Image(systemName: "pin.fill").accessibilityLabel("Pinned") }
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                }.font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
