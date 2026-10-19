import AppKit
import Carbon
import SwiftUI

struct ShortcutConfiguration: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String

    static let standard = ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(controlKey | optionKey), keyLabel: "V")

    var label: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + keyLabel
    }
}

/// Carbon's system hot-key registration does not require Accessibility access.
@MainActor
final class GlobalShortcut: ObservableObject {
    @Published private(set) var configuration: ShortcutConfiguration
    @Published private(set) var isEnabled: Bool
    @Published var errorMessage: String?
    var action: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var isRecording = false

    init() {
        configuration = UserDefaults.standard.data(forKey: "historyShortcut")
            .flatMap { try? JSONDecoder().decode(ShortcutConfiguration.self, from: $0) } ?? .standard
        isEnabled = UserDefaults.standard.object(forKey: "historyShortcutEnabled") as? Bool ?? true
    }

    func start() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in shortcut.action?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            errorMessage = "Could not enable the global keyboard shortcut (\(status))."
            return
        }
        if isEnabled, !register(configuration) {
            isEnabled = false
            errorMessage = "\(configuration.label) is unavailable. Choose another shortcut in Settings."
        }
    }

    func setRecording(_ recording: Bool) {
        guard recording != isRecording else { return }
        isRecording = recording
        if recording { unregister() }
        else if isEnabled, !register(configuration) {
            isEnabled = false
            errorMessage = "The shortcut became unavailable. Choose another combination."
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if enabled, !register(configuration) {
            errorMessage = "\(configuration.label) is already in use. Choose another shortcut."
            return
        }
        if !enabled { unregister() }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "historyShortcutEnabled")
    }

    func setConfiguration(_ proposed: ShortcutConfiguration) {
        guard proposed != configuration || !isEnabled else { return }
        let previous = configuration
        let wasEnabled = isEnabled
        unregister()
        guard register(proposed) else {
            if wasEnabled { _ = register(previous) }
            errorMessage = "\(proposed.label) is unavailable or used by another app. Your previous shortcut has been kept."
            return
        }
        configuration = proposed
        isEnabled = true
        UserDefaults.standard.set(try? JSONEncoder().encode(proposed), forKey: "historyShortcut")
        UserDefaults.standard.set(true, forKey: "historyShortcutEnabled")
    }

    private func register(_ shortcut: ShortcutConfiguration) -> Bool {
        let identifier = EventHotKeyID(signature: 0x434C4950, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier,
            GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let configuration: ShortcutConfiguration
    let onRecord: (ShortcutConfiguration) -> Void
    let onRecordingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecordButton {
        let button = ShortcutRecordButton(frame: .zero)
        button.bezelStyle = .rounded
        button.setAccessibilityLabel("Record keyboard shortcut")
        return button
    }

    func updateNSView(_ button: ShortcutRecordButton, context: Context) {
        button.shortcutTitle = configuration.label
        button.onRecord = onRecord
        button.onRecordingChanged = onRecordingChanged
        if !button.isRecording { button.title = configuration.label }
    }

    static func dismantleNSView(_ button: ShortcutRecordButton, coordinator: ()) {
        button.cancelRecording()
    }
}

final class ShortcutRecordButton: NSButton {
    var onRecord: ((ShortcutConfiguration) -> Void)?
    var shortcutTitle = ""
    var onRecordingChanged: ((Bool) -> Void)?
    private(set) var isRecording = false
    private var recordingMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        target = self
        action = #selector(record)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    @objc private func record() {
        if isRecording { finish(); return }
        guard let window else { return }
        isRecording = true
        onRecordingChanged?(true)
        title = "Press shortcut…"
        window.makeFirstResponder(self)
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
            object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.finish() }
            }
        // Intercept locally before menu key equivalents (such as ⌘Q) can run.
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.type != .keyDown {
                if event.window !== self.window || !self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    self.finish()
                }
                return event
            }
            guard event.window === self.window, self.window?.firstResponder === self else { return event }
            self.keyDown(with: event)
            return nil
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) { finish(); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let knownLabels: [Int: String] = [kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Home: "Home", kVK_End: "End",
            kVK_PageUp: "Page Up", kVK_PageDown: "Page Down", kVK_UpArrow: "↑",
            kVK_DownArrow: "↓", kVK_LeftArrow: "←", kVK_RightArrow: "→"]
        let functionCodes = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
            kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        let functionLabel = functionCodes.firstIndex(of: Int(event.keyCode)).map { "F\($0 + 1)" }
        let characters = event.charactersIgnoringModifiers ?? ""
        let printable = !characters.isEmpty && characters.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
        guard !flags.intersection([.command, .option, .control]).isEmpty,
              knownLabels[Int(event.keyCode)] != nil || functionLabel != nil || printable else {
            NSSound.beep()
            return
        }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let keyLabel = knownLabels[Int(event.keyCode)] ?? functionLabel ?? characters.uppercased()
        finish()
        onRecord?(ShortcutConfiguration(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: keyLabel))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        finish()
        return super.resignFirstResponder()
    }

    func cancelRecording() { finish() }

    private func finish() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        let wasRecording = isRecording
        isRecording = false
        title = shortcutTitle
        if wasRecording { onRecordingChanged?(false) }
    }
}
