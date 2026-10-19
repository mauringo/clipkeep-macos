import SwiftUI
import ClipboardCore
import ServiceManagement

private typealias SettingsState<Value> = SwiftUI.State<Value>

struct SettingsView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let dismiss: () -> Void
    @SettingsState private var loginStatus = SMAppService.mainApp.status
    @SettingsState private var changingLoginItem = false
    @SettingsState private var limitText: String
    @SettingsState private var confirmClean = false
    @SettingsState private var errorMessage: String?

    init(monitor: ClipboardMonitor, dismiss: @escaping () -> Void) {
        self.monitor = monitor
        self.dismiss = dismiss
        _limitText = SettingsState(initialValue: String(monitor.settings.maximumEntries))
    }

    private var validLimit: Int? {
        guard let value = Int(limitText.trimmingCharacters(in: .whitespaces)),
              HistorySettings.allowedLimits.contains(value) else { return nil }
        return value
    }

    private func updateLoginItem(enabled: Bool) {
        changingLoginItem = true
        Task { @MainActor in
            defer {
                loginStatus = SMAppService.mainApp.status
                changingLoginItem = false
            }
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                errorMessage = "Could not change Start at login. Install and run the app from Applications, then try again. \(error.localizedDescription)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Clipboard settings", systemImage: "gearshape")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Start at login", isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: { enabled in updateLoginItem(enabled: enabled) }
                ))
                .toggleStyle(.switch)
                .disabled(changingLoginItem)
                Text("Start quietly in the menu bar when you sign in to your Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                if loginStatus == .requiresApproval {
                    Text("Waiting for approval in macOS Login Items.")
                        .font(.callout).foregroundStyle(.orange)
                    Button("Open Login Items Settings…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Keep history after restart or reboot", isOn: Binding(
                    get: { monitor.settings.keepAfterRestart },
                    set: { enabled in
                        do {
                            try monitor.applySettings(HistorySettings(
                                maximumEntries: monitor.settings.maximumEntries,
                                keepAfterRestart: enabled))
                        } catch { errorMessage = error.localizedDescription }
                    }
                ))
                .toggleStyle(.switch)
                Text(monitor.settings.keepAfterRestart
                     ? "Save clipboard history on this Mac and restore it when the app opens again."
                     : "Keep history in memory only. Saved history is removed immediately; current entries remain available until you quit.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum entries")
                    Spacer()
                    TextField("100", text: $limitText)
                        .textFieldStyle(.roundedBorder).frame(width: 90)
                        .accessibilityLabel("Maximum clipboard history entries")
                }
                Text("Choose 1–1,000 entries. Reducing the limit removes the oldest entries when you apply.")
                    .font(.callout).foregroundStyle(validLimit == nil ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Clean history").fontWeight(.medium)
                    Text("Remove all \(monitor.entries.count) entries from the app. Your system clipboard and exported files stay available.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Clean history…", role: .destructive) { confirmClean = true }
                    .disabled(monitor.entries.isEmpty)
            }

            HStack {
                Spacer()
                Button("Close", action: dismiss).keyboardShortcut(.cancelAction)
                Button("Apply limit") {
                    guard let limit = validLimit else { return }
                    do {
                        try monitor.applySettings(HistorySettings(maximumEntries: limit,
                                                                  keepAfterRestart: monitor.settings.keepAfterRestart))
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(validLimit == nil || validLimit == monitor.settings.maximumEntries)
            }.padding(.top, 4)
        }.padding(24).frame(width: 480)
        .onAppear { loginStatus = SMAppService.mainApp.status }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
        .alert("Clean clipboard history?", isPresented: $confirmClean) {
            Button("Cancel", role: .cancel) {}
            Button("Clean history", role: .destructive) {
                do { try monitor.cleanHistory() }
                catch { errorMessage = error.localizedDescription }
            }
        } message: { Text("This permanently removes all entries saved by the app.") }
        .alert("Could not update settings", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
