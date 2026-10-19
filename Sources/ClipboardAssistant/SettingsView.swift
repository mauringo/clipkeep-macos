import SwiftUI
import ClipboardCore
import ServiceManagement

private typealias SettingsState<Value> = SwiftUI.State<Value>

struct SettingsView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var shortcut: GlobalShortcut
    let dismiss: () -> Void
    @SettingsState private var loginStatus = SMAppService.mainApp.status
    @SettingsState private var changingLoginItem = false
    @SettingsState private var limitText: String
    @SettingsState private var confirmClean = false
    @SettingsState private var errorMessage: String?

    init(monitor: ClipboardMonitor, shortcut: GlobalShortcut, dismiss: @escaping () -> Void) {
        self.monitor = monitor
        self.shortcut = shortcut
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

    private func chooseExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Exclude an app from clipboard capture"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let id = Bundle(url: url)?.bundleIdentifier else {
            errorMessage = "Could not identify that app. Choose an installed .app bundle."
            return
        }
        var preferences = monitor.capturePreferences
        preferences.excludedBundleIDs.insert(id)
        monitor.setCapturePreferences(preferences)
    }

    private func appName(_ id: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?
            .deletingPathExtension().lastPathComponent ?? id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Clipboard settings", systemImage: "gearshape")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("Keyboard shortcut", isOn: Binding(
                            get: { shortcut.isEnabled }, set: { shortcut.setEnabled($0) }
                        )).toggleStyle(.switch)
                        Spacer()
                        ShortcutRecorder(configuration: shortcut.configuration,
                            onRecord: { shortcut.setConfiguration($0) },
                            onRecordingChanged: { shortcut.setRecording($0) })
                            .frame(width: 170, height: 28)
                    }
                    Text("Click the shortcut and press your own combination with ⌘, ⌥, or ⌃. Escape cancels recording. In history, use ↑/↓ to select and Return to copy and close.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Reset shortcut") { shortcut.setConfiguration(.standard) }.font(.caption)
                }

                Divider()
                DisclosureGroup("Capture & privacy") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Ignore confidential and temporary clipboard content", isOn: Binding(
                            get: { monitor.capturePreferences.ignoreSensitiveContent },
                            set: { value in
                                var preferences = monitor.capturePreferences
                                preferences.ignoreSensitiveContent = value
                                monitor.setCapturePreferences(preferences)
                            }
                        ))
                        Text("Respects privacy markers supplied by other apps. Unmarked passwords cannot be identified reliably; exclude their app or stop capture.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(monitor.capturePreferences.excludedBundleIDs.sorted(), id: \.self) { id in
                            HStack {
                                Text(appName(id)).lineLimit(1).help(id)
                                Spacer()
                                Button {
                                    var preferences = monitor.capturePreferences
                                    preferences.excludedBundleIDs.remove(id)
                                    monitor.setCapturePreferences(preferences)
                                } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel("Remove exclusion for \(appName(id))")
                            }
                        }
                        Button("Exclude an app…", action: chooseExcludedApp)
                        Text("Exclusions apply to future copies. App identity uses the clipboard source when provided, otherwise the app active at capture time.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }

                Toggle("Recognize text in images", isOn: Binding(
                    get: { monitor.capturePreferences.recognizeTextInImages },
                    set: { value in
                        var preferences = monitor.capturePreferences
                        preferences.recognizeTextInImages = value
                        monitor.setCapturePreferences(preferences)
                    }
                ))
                Text("Read and search text in captured images using on-device recognition. Images stay on your Mac. Turning this off stops new recognition; existing recognized text stays available.")
                    .font(.caption).foregroundStyle(.secondary)

                Divider()

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
                    Text("Choose 1–1,000 recent entries. Pinned items are kept in addition to this limit, for as long as history retention allows.")
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
            }.padding(24)
        }.frame(width: 480, height: 600)
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
            get: { errorMessage != nil || shortcut.errorMessage != nil },
            set: { if !$0 { errorMessage = nil; shortcut.errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil; shortcut.errorMessage = nil }
        } message: { Text(errorMessage ?? shortcut.errorMessage ?? "") }
    }
}
