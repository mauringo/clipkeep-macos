import AppKit
import ClipboardCore

/// Checks release metadata only; clipboard contents never enter a request.
@MainActor
final class UpdateChecker {
    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [BinaryReleaseAsset]
    }

    private let defaults = UserDefaults.standard
    private let automaticKey = "automaticallyCheckForUpdates"
    private let lastCheckKey = "lastSuccessfulUpdateCheck"
    private var timer: Timer?
    private var updateProcess: Process?
    private var isInstalling = false
    private var progressWindow: NSWindow?
    private(set) var isChecking = false

    var automaticallyChecks: Bool {
        get { defaults.object(forKey: automaticKey) as? Bool ?? false }
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
        guard !isChecking, !isInstalling, updateProcess == nil else { return }
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
                    alert.informativeText = "You have version \(currentString). Install Update downloads a prebuilt app, verifies its checksum and code integrity, replaces this app, and relaunches it. Saved history is preserved; session-only history is lost on restart. If you installed with Homebrew, use brew upgrade instead."
                    alert.addButton(withTitle: "Install Update")
                    alert.addButton(withTitle: "Later")
                    if manual { NSApp.activate(ignoringOtherApps: true) }
                    if alert.runModal() == .alertFirstButtonReturn {
                        installUpdate(release: release)
                    }
                } else if manual {
                    showMessage("You’re up to date", "Clipboard Assistant \(currentString) is the latest release.")
                }
            } catch {
                if manual { showMessage("Could not check for updates", "Please try again later. \(error.localizedDescription)") }
            }
        }
    }

    private func installUpdate(release: Release) {
        guard !isInstalling, updateProcess == nil else { return }
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        guard let asset = release.assets.first(where: { $0.isValid(for: release.tag_name, architecture: architecture) })
            ?? release.assets.first(where: { $0.isValid(for: release.tag_name, architecture: "universal") }) else {
            showMessage("No compatible download", BinaryUpdate.Failure.invalidAsset.localizedDescription)
            return
        }
        let assetArchitecture = asset.name.hasSuffix("-universal.zip") ? "universal" : architecture
        guard let helper = Bundle.main.url(forResource: "install-app", withExtension: "sh") else {
            showMessage("Could not start update", "The installer helper is missing. Use Homebrew or reinstall the app.")
            return
        }
        let appURL = Bundle.main.bundleURL
        isInstalling = true
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 140),
            styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "Updating Clipboard Assistant"
        panel.isReleasedWhenClosed = false
        let label = NSTextField(wrappingLabelWithString:
            "Downloading and verifying \(release.tag_name)…\nThe app will quit and reopen when installation is ready.")
        label.frame = NSRect(x: 20, y: 45, width: 420, height: 70)
        let spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 16, width: 420, height: 16))
        spinner.style = .bar; spinner.isIndeterminate = true; spinner.startAnimation(nil)
        panel.contentView?.addSubview(label); panel.contentView?.addSubview(spinner)
        panel.center(); panel.makeKeyAndOrderFront(nil)
        progressWindow = panel
        Task { @MainActor [self] in
            var staging: URL?
            do {
                let destination = UpdateDestination.resolve(appURL: appURL,
                    parentIsWritable: FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path),
                    homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-binary-update-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                    attributes: [.posixPermissions: 0o700])
                staging = directory
                let session = URLSession(configuration: .ephemeral)
                defer { session.finishTasksAndInvalidate() }
                var request = URLRequest(url: asset.browser_download_url)
                request.timeoutInterval = 120
                let (download, response) = try await session.download(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.invalidResponse }
                let archive = directory.appendingPathComponent("update.zip")
                try FileManager.default.moveItem(at: download, to: archive)
                let app = try await Task.detached(priority: .userInitiated) {
                    try BinaryUpdate.prepare(archive: archive, asset: asset, tag: release.tag_name,
                        architecture: assetArchitecture, directory: directory.appendingPathComponent("unpacked"))
                }.value
                // Copy the trusted helper before replacing this bundle. It remains available after the app quits.
                let stagedHelper = directory.appendingPathComponent("install-app.sh")
                try FileManager.default.copyItem(at: helper, to: stagedHelper)
                let runner = directory.appendingPathComponent("run.zsh")
                try "#!/bin/zsh\nset -euo pipefail\ntrap 'rm -rf \"$3\"' EXIT\n/bin/zsh \"$1\" \"$2\"\n".write(to: runner, atomically: true, encoding: .utf8)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = [runner.path, stagedHelper.path, app.path, directory.path]
                var environment = ProcessInfo.processInfo.environment
                environment["CLIPBOARD_APPLICATIONS_DIR"] = destination.deletingLastPathComponent().path
                process.environment = environment
                process.terminationHandler = { [weak self] process in
                    Task { @MainActor in
                        self?.updateProcess = nil; self?.isInstalling = false
                        self?.progressWindow?.close(); self?.progressWindow = nil
                        if process.terminationStatus != 0 {
                            self?.showMessage("Update could not be installed", "Use Homebrew or the Finder installer to update. Your existing app is still available.")
                        }
                    }
                }
                try process.run()
                updateProcess = process
            } catch {
                if let staging { try? FileManager.default.removeItem(at: staging) }
                isInstalling = false
                progressWindow?.close(); progressWindow = nil
                showMessage("Update could not be installed", error.localizedDescription)
            }
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
