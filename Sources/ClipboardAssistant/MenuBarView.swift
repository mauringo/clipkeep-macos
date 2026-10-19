import SwiftUI
import ClipboardCore

private typealias MenuState<Value> = SwiftUI.State<Value>

/// Compact, transient history attached to the menu-bar icon.
struct MenuBarView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let expand: () -> Void
    let showSettings: () -> Void
    let checkForUpdates: () -> Void
    let dismiss: () -> Void
    let quit: () -> Void
    @MenuState private var search = ""

    private var entries: [ClipboardEntry] {
        monitor.entries.filter {
            search.isEmpty || ($0.text ?? "Copied image").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard Assistant").font(.headline)
                    Text("\(monitor.entries.count) entries · \(monitor.isMonitoring ? "Capturing" : "Paused")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: expand) {
                    Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                }.help("Open the full app")
            }.padding(16)
            TextField("Search clipboard history", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.bottom, 12)
            Divider()
            if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard").font(.largeTitle)
                    Text(monitor.entries.isEmpty ? "Copy text or an image to get started." : "No matching entries")
                        .font(.callout).multilineTextAlignment(.center)
                }.foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            Button {
                                monitor.copy(entry)
                                dismiss()
                            } label: {
                                HistoryRow(entry: entry).padding(.horizontal, 14)
                            }
                            .buttonStyle(.plain)
                            .help("Copy this entry")
                            .onDrag { EntryDragProvider.make(for: entry) }
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button(action: showSettings) { Label("Settings…", systemImage: "gearshape") }
                Spacer()
                Button { monitor.isMonitoring.toggle() } label: {
                    Image(systemName: monitor.isMonitoring ? "pause.fill" : "play.fill")
                }.help(monitor.isMonitoring ? "Pause capture" : "Resume capture")
                    .accessibilityLabel(monitor.isMonitoring ? "Pause capture" : "Resume capture")
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
        .frame(width: 380, height: 500)
        .onExitCommand(perform: dismiss)
        .alert("Clipboard Assistant", isPresented: Binding(
            get: { monitor.errorMessage != nil },
            set: { if !$0 { monitor.errorMessage = nil } }
        )) {
            Button("OK") { monitor.errorMessage = nil }
        } message: { Text(monitor.errorMessage ?? "") }
    }
}
