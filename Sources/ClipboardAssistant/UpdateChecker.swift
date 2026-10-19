import AppKit
import ClipboardCore

/// Checks release metadata only; clipboard contents never enter a request.
@MainActor
final class UpdateChecker {
    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
    }

    private let defaults = UserDefaults.standard
    private let automaticKey = "automaticallyCheckForUpdates"
    private let lastCheckKey = "lastSuccessfulUpdateCheck"
    private var timer: Timer?
    private var updateProcess: Process?
    private var progressWindow: NSWindow?
    private(set) var isChecking = false

    var automaticallyChecks: Bool {
        get { defaults.object(forKey: automaticKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: automaticKey) }
    }

    func start() {
        checkAutomaticallyIfDue()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkAutomaticallyIfDue() }
        }
    }

    func checkAutomaticallyIfDue() {
        guard automaticallyChecks else { return }
        let last = defaults.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= 86_400 else { return }
        check(manual: false)
    }

    func check(manual: Bool) {
        guard !isChecking, updateProcess == nil else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                let currentString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                guard let current = ReleaseVersion(currentString) else {
                    throw UpdateError.invalidVersion
                }
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/mauringo/clipkeep-macos/releases/latest")!)
                request.timeoutInterval = 20
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("ClipboardAssistant/\(currentString)", forHTTPHeaderField: "User-Agent")
                // Ephemeral configuration avoids persisting GitHub cookies or HTTP caches.
                let session = URLSession(configuration: .ephemeral)
                defer { session.finishTasksAndInvalidate() }
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
                if response.statusCode == 404 {
                    if manual { showMessage("No releases available", "No published release is available yet. Try again later.") }
                    return
                }
                guard response.statusCode == 200 else { throw UpdateError.http(response.statusCode) }
                let release = try JSONDecoder().decode(Release.self, from: data)
                guard !release.draft, !release.prerelease,
                      let latest = ReleaseVersion(release.tag_name) else { throw UpdateError.invalidResponse }
                defaults.set(Date(), forKey: lastCheckKey)
                if latest > current {
                    let alert = NSAlert()
                    alert.messageText = "Clipboard Assistant \(release.tag_name) is available"
                    alert.informativeText = "You have version \(currentString). Install Update downloads this release’s source from GitHub, builds it on your Mac, replaces this app, and relaunches it. Apple Command Line Tools (Swift 6+) and internet access are required. Your current app stays available during the build."
                    alert.addButton(withTitle: "Install Update")
                    alert.addButton(withTitle: "Later")
                    if manual { NSApp.activate(ignoringOtherApps: true) }
                    if alert.runModal() == .alertFirstButtonReturn {
                        installUpdate(tag: release.tag_name)
                    }
                } else if manual {
                    showMessage("You’re up to date", "Clipboard Assistant \(currentString) is the latest release.")
                }
            } catch {
                if manual { showMessage("Could not check for updates", "Please try again later. \(error.localizedDescription)") }
            }
        }
    }

    private func installUpdate(tag: String) {
        guard updateProcess == nil else { return }
        let appURL = Bundle.main.bundleURL
        guard let script = Bundle.main.url(forResource: "update-from-source", withExtension: "sh") else {
            showMessage("Could not start update", "The update helper is missing. Reinstall Clipboard Assistant and try again.")
            return
        }
        do {
            let destination = UpdateDestination.resolve(appURL: appURL,
                parentIsWritable: FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path),
                homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let logDirectory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("ClipboardAssistant/Updates", isDirectory: true)
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let logURL = logDirectory.appendingPathComponent("update.log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil,
                attributes: [.posixPermissions: 0o600])
            let log = try FileHandle(forWritingTo: logURL)
            try log.truncate(atOffset: 0)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [script.path, tag, destination.path]
            process.standardOutput = log
            process.standardError = log
            process.terminationHandler = { [weak self] process in
                try? log.close()
                Task { @MainActor in
                    guard let self else { return }
                    self.updateProcess = nil
                    self.progressWindow?.close()
                    self.progressWindow = nil
                    if process.terminationStatus != 0 {
                        self.showMessage("Update could not be installed",
                            "Your existing app is still available. Check that Apple Command Line Tools (Swift 6+) are installed and try again. Build details: \(logURL.path)")
                        NSWorkspace.shared.selectFile(logURL.path, inFileViewerRootedAtPath: logDirectory.path)
                    }
                }
            }
            try process.run()
            updateProcess = process
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 160),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "Updating Clipboard Assistant"
            panel.isReleasedWhenClosed = false
            let label = NSTextField(wrappingLabelWithString:
                "Downloading and building \(tag)…\nYou can keep using the app. It will quit and reopen when installation is ready. Closing this window leaves the update running." +
                (destination == appURL ? "" : " The updated app will be installed in your Applications folder."))
            label.frame = NSRect(x: 20, y: 45, width: 420, height: 95)
            let spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 16, width: 420, height: 16))
            spinner.style = .bar
            spinner.isIndeterminate = true
            spinner.startAnimation(nil)
            panel.contentView?.addSubview(label)
            panel.contentView?.addSubview(spinner)
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            progressWindow = panel
        } catch {
            showMessage("Could not start update", error.localizedDescription)
        }
    }

    private func showMessage(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private enum UpdateError: LocalizedError {
        case invalidVersion, invalidResponse, http(Int)
        var errorDescription: String? {
            switch self {
            case .invalidVersion: return "The installed app has no valid release version."
            case .invalidResponse: return "GitHub returned unexpected release metadata."
            case .http(let code): return "GitHub returned HTTP \(code)."
            }
        }
    }
}
