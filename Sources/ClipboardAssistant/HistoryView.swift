import SwiftUI
import ClipboardCore

// A type alias selects the property wrapper on SDKs that also expose a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct HistoryView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ViewState private var selection: UUID?
    @ViewState private var search = ""
    @ViewState private var filter = EntryFilter.all
    @ViewState private var confirmClear = false
    @ViewState private var copiedID: UUID?

    private enum EntryFilter: String, CaseIterable {
        case all = "All", text = "Text", image = "Images"
    }

    private var filtered: [ClipboardEntry] {
        monitor.entries.filter { entry in
            (filter == .all || (filter == .text && entry.kind == .text) ||
             (filter == .image && entry.kind == .image)) &&
            (search.isEmpty || (entry.text ?? "Image").localizedCaseInsensitiveContains(search))
        }
    }

    private var selected: ClipboardEntry? {
        filtered.first(where: { $0.id == selection })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "clipboard.fill")
                    .font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Clipboard Assistant").font(.headline)
                    Text("\(monitor.entries.count) of 100 entries · Saved on this Mac")
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
            }
            .padding(20)
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
                        List(filtered, selection: $selection) { entry in
                            HistoryRow(entry: entry).tag(entry.id)
                                .contextMenu {
                                    Button("Copy") { monitor.copy(entry) }
                                    Button("Save to…") { monitor.save(entry) }
                                    Divider()
                                    Button("Delete", role: .destructive) { monitor.remove(entry) }
                                }
                        }.listStyle(.sidebar)
                    }
                    Divider()
                    HStack {
                        Text("Newest first").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear history…") { confirmClear = true }
                            .buttonStyle(.borderless).font(.caption)
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
                            GeometryReader { geometry in
                                Image(nsImage: image).resizable().scaledToFit()
                                    .frame(width: max(0, geometry.size.width - 48),
                                           height: max(0, geometry.size.height - 48))
                                    .padding(24)
                            }
                            Divider()
                            HStack {
                                Text("PNG image · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                                Spacer()
                            }.font(.caption).foregroundStyle(.secondary).padding(14)
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
        .onAppear { selection = monitor.entries.first?.id }
        .onChange(of: monitor.entries.map(\.id)) { ids in
            if selection == nil || !ids.contains(selection!) { selection = ids.first }
        }
        .alert("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear history", role: .destructive) { monitor.clear() }
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

private struct HistoryRow: View {
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
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }
}
