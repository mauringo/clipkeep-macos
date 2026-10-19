import AppKit
import Combine
import SwiftUI

/// Defers native close requests until the preview's shared animation finishes.
@MainActor
final class PreviewPopover: NSObject, ObservableObject, NSPopoverDelegate {
    enum Navigation { case previous, next, activate, focusSearch }
    let navigation = PassthroughSubject<Navigation, Never>()
    let popover = NSPopover()
    private var keyboardMonitor: Any?
    @Published private(set) var isClosing = false
    @Published private(set) var showsPreview = UserDefaults.standard.object(forKey: "showsMenuPreview") as? Bool ?? true

    var contentSize: NSSize {
        NSSize(width: showsPreview ? 760 : 350, height: showsPreview ? 520 : 430)
    }

    func togglePreviewPane() {
        showsPreview.toggle()
        UserDefaults.standard.set(showsPreview, forKey: "showsMenuPreview")
        popover.contentSize = contentSize
    }
    private var closeTask: Task<Void, Never>?

    override init() {
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    func dismiss() {
        guard popover.isShown, !isClosing,
              popover.contentViewController?.view.window?.attachedSheet == nil,
              NSApp.modalWindow == nil else { return }
        withAnimation(.easeInOut(duration: 0.22)) { isClosing = true }
        closeTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 220_000_000) }
            catch { return }
            guard let self, !Task.isCancelled else { return }
            // close() bypasses popoverShouldClose, avoiding another close request.
            // SwiftUI has already animated out the content, so don't animate twice.
            self.popover.animates = false
            self.popover.close()
        }
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        dismiss()
        return false
    }

    func popoverWillShow(_ notification: Notification) {
        reset()
    }

    func popoverDidShow(_ notification: Notification) {
        navigation.send(.focusSearch)
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown, !self.isClosing,
                  let window = self.popover.contentViewController?.view.window,
                  event.window === window, window.isKeyWindow,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
            // Arrow keys in selectable preview text retain their normal editing behavior.
            if let text = self.popover.contentViewController?.view.window?.firstResponder as? NSTextView,
               !text.isFieldEditor { return event }
            switch event.keyCode {
            case 125: self.navigation.send(.next)
            case 126: self.navigation.send(.previous)
            case 36, 76: self.navigation.send(.activate)
            default: return event
            }
            return nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        keyboardMonitor = nil
        reset()
    }

    private func reset() {
        // A forced close or a new opening must not leave a delayed close pending.
        closeTask?.cancel()
        closeTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isClosing = false }
        popover.animates = true
    }
}
