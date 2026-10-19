import AppKit
import SwiftUI

/// Defers native close requests until the preview's shared animation finishes.
@MainActor
final class PreviewPopover: NSObject, ObservableObject, NSPopoverDelegate {
    let popover = NSPopover()
    @Published private(set) var isClosing = false
    private var closeTask: Task<Void, Never>?

    override init() {
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    func dismiss() {
        guard popover.isShown, !isClosing else { return }
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

    func popoverDidClose(_ notification: Notification) {
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
