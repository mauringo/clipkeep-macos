import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var window: NSWindow!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var applicationMenu: NSMenu!
    private var monitor: ClipboardMonitor!
    private let updateChecker = UpdateChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = ClipboardMonitor()
        let menu = NSMenu()
        menu.addItem(withTitle: "About Clipboard Assistant", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(withTitle: "Automatically Check for Updates", action: #selector(toggleAutomaticUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Clipboard History", action: #selector(showWindow), keyEquivalent: "0")
        menu.addItem(withTitle: "Pause Capture", action: #selector(toggleCapture), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clipboard Assistant", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        menu.delegate = self
        applicationMenu = menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Assistant")
        // Left-click opens the compact history; right-click offers app commands.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "Open Clipboard Assistant"

        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = menu
        appMenu.addItem(appMenuItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        appMenu.addItem(editItem)
        NSApp.mainMenu = appMenu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Clipboard Assistant"
        window.contentView = NSHostingView(rootView: HistoryView(monitor: monitor,
            showSettings: { [weak self] in self?.showSettings() }))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ClipboardHistoryWindow")
        window.center()
        window.delegate = self
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 760, height: 520)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            monitor: monitor,
            expand: { [weak self] in self?.showWindow() },
            showSettings: { [weak self] in self?.showSettings() },
            checkForUpdates: { [weak self] in
                self?.popover.performClose(nil)
                self?.checkForUpdates()
            },
            dismiss: { [weak self] in self?.dismissPreview() },
            quit: { [weak self] in self?.quit() }))
        monitor.start()
        updateChecker.start()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.items.first(where: { $0.action == #selector(toggleAutomaticUpdates) })?.state =
            updateChecker.automaticallyChecks ? .on : .off
        menu.items.first(where: { $0.action == #selector(toggleCapture) })?.title =
            monitor.isMonitoring ? "Pause Capture" : "Resume Capture"
    }

    private func dismissPreview() {
        // The preview animates its content before closing. Avoid a second native
        // animation, so its state can reset offscreen for the next opening.
        popover.animates = false
        popover.performClose(nil)
        popover.animates = true
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            statusItem.menu = applicationMenu
            button.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func showWindow() {
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleCapture() { monitor.isMonitoring.toggle() }
    @objc private func showSettings() {
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            let settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 528, height: 650),
                                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings.title = "Clipboard Settings"
            settings.isReleasedWhenClosed = false
            settings.delegate = self
            settings.contentView = NSHostingView(rootView: SettingsView(monitor: monitor,
                dismiss: { [weak self] in self?.settingsWindow?.close() }))
            settings.center()
            settingsWindow = settings
            settings.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func checkForUpdates() { updateChecker.check(manual: true) }
    @objc private func toggleAutomaticUpdates() {
        updateChecker.automaticallyChecks.toggle()
        updateChecker.checkAutomaticallyIfDue()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showAbout() { NSApp.orderFrontStandardAboutPanel(nil) }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        let hasOtherWindow = [window, settingsWindow].compactMap { $0 }.contains {
            $0 !== closing && $0.isVisible
        }
        if !hasOtherWindow { NSApp.setActivationPolicy(.accessory) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
