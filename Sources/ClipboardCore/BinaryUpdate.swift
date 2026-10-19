import Foundation
import CryptoKit

public struct BinaryReleaseAsset: Decodable, Sendable {
    public let name: String
    public let browser_download_url: URL
    public let digest: String?
    public let size: Int64

    public init(name: String, url: URL, digest: String?, size: Int64) {
        self.name = name; browser_download_url = url; self.digest = digest; self.size = size
    }

    public func isValid(for tag: String, architecture: String) -> Bool {
        guard ReleaseVersion(tag) != nil, ["arm64", "x86_64", "universal"].contains(architecture) else { return false }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let expected = "ClipboardAssistant-\(version)-\(architecture).zip"
        guard name == expected, size > 0, size <= 256 * 1_024 * 1_024,
              browser_download_url.absoluteString == "https://github.com/mauringo/clipkeep-macos/releases/download/\(tag)/\(expected)",
              let digest, digest.hasPrefix("sha256:") else { return false }
        let hash = digest.dropFirst(7)
        return hash.count == 64 && hash.allSatisfy { $0.isASCII && $0.isHexDigit }
    }
}

public enum BinaryUpdate {
    public enum Failure: LocalizedError, Equatable {
        case invalidAsset, checksum, unsafeArchive, invalidBundle, tool(String)
        public var errorDescription: String? {
            switch self {
            case .invalidAsset: return "No verified app download is available for this Mac. Use Homebrew or download a compatible release."
            case .checksum: return "The update's download size or SHA-256 checksum did not match GitHub's release metadata."
            case .unsafeArchive: return "The update archive contains unexpected file paths."
            case .invalidBundle: return "The downloaded app has an unexpected identity or release version."
            case .tool(let message): return "Could not prepare the update: \(message)"
            }
        }
    }

    public static func verify(_ data: Data, asset: BinaryReleaseAsset) throws {
        let actual = "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == asset.size, actual == asset.digest?.lowercased() else { throw Failure.checksum }
    }

    public static func validateArchivePaths(_ paths: [String]) throws {
        guard !paths.isEmpty, paths.allSatisfy({ path in
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            let isApp = parts.first == "Clipboard Assistant.app"
            let isMetadata = path == "__MACOSX/" ||
                (parts.first == "__MACOSX" && parts.dropFirst().first == "Clipboard Assistant.app")
            return !path.hasPrefix("/") && (isApp || isMetadata) && !parts.contains("..")
                && !path.contains("\\")
        }) else { throw Failure.unsafeArchive }
    }

    /// Validate the downloaded bytes, archive paths, app identity, version, and code integrity before installation.
    public static func prepare(archive: URL, asset: BinaryReleaseAsset, tag: String, architecture: String,
                               directory: URL) throws -> URL {
        guard asset.isValid(for: tag, architecture: architecture) else { throw Failure.invalidAsset }
        let size = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size == asset.size else { throw Failure.checksum }
        try verify(Data(contentsOf: archive, options: .mappedIfSafe), asset: asset)
        let listing = try run("/usr/bin/zipinfo", ["-1", archive.path])
        try validateArchivePaths(listing.split(whereSeparator: \.isNewline).map(String.init))
        // This app's bundles do not need symlinks. Reject them before extraction,
        // so a crafted link cannot redirect a later archive member outside staging.
        let details = try run("/usr/bin/zipinfo", ["-l", archive.path])
        guard !details.split(whereSeparator: \.isNewline).contains(where: { $0.first == "l" }) else {
            throw Failure.unsafeArchive
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try run("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
        let app = directory.appendingPathComponent("Clipboard Assistant.app", isDirectory: true)
        let info = app.appendingPathComponent("Contents/Info.plist")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: info), format: nil) as? [String: Any]
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard plist?["CFBundleIdentifier"] as? String == "com.clipboardassistant.mac",
              plist?["CFBundleShortVersionString"] as? String == version,
              plist?["CFBundleExecutable"] as? String == "ClipboardAssistant",
              try app.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw Failure.invalidBundle }
        _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        return app
    }

    private static func run(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw Failure.tool(String(text.prefix(1_000))) }
        return text
    }
}
