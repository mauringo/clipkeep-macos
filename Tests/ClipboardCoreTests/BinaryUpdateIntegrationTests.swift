import Foundation
import CryptoKit
import Testing
@testable import ClipboardCore

struct BinaryUpdateIntegrationTests {
    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output; process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(String(decoding: data, as: UTF8.self))")
    }

    @Test func preparesARealSignedArchiveAndRejectsWrongIdentityAndDamagedCode() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = directory.appendingPathComponent("Clipboard Assistant.app")
        let executableDirectory = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("main.c")
        try "int main(void) { return 0; }".write(to: source, atomically: true, encoding: .utf8)
        let executable = executableDirectory.appendingPathComponent("ClipboardAssistant")
        try run("/usr/bin/clang", [source.path, "-o", executable.path])
        let info = app.appendingPathComponent("Contents/Info.plist")
        let base: [String: Any] = ["CFBundleIdentifier": "com.clipboardassistant.mac",
            "CFBundleShortVersionString": "1.7.0", "CFBundleExecutable": "ClipboardAssistant", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: base, format: .xml, options: 0).write(to: info)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])

        func archive(_ name: String) throws -> (URL, BinaryReleaseAsset) {
            let zip = directory.appendingPathComponent(name + ".zip")
            try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", app.path, zip.path])
            let bytes = try Data(contentsOf: zip)
            let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            return (zip, BinaryReleaseAsset(name: "ClipboardAssistant-1.7.0-arm64.zip",
                url: URL(string: "https://github.com/mauringo/clipkeep-macos/releases/download/v1.7.0/ClipboardAssistant-1.7.0-arm64.zip")!,
                digest: "sha256:" + hash, size: Int64(bytes.count)))
        }
        let (good, goodAsset) = try archive("good")
        let prepared = try BinaryUpdate.prepare(archive: good, asset: goodAsset, tag: "v1.7.0",
            architecture: "arm64", directory: directory.appendingPathComponent("prepared"))
        #expect(FileManager.default.fileExists(atPath: prepared.appendingPathComponent("Contents/MacOS/ClipboardAssistant").path))

        var wrong = base
        wrong["CFBundleIdentifier"] = "com.example.wrong"
        try PropertyListSerialization.data(fromPropertyList: wrong, format: .xml, options: 0).write(to: info)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        let (wrongZip, wrongAsset) = try archive("wrong")
        #expect(throws: (any Error).self) {
            try BinaryUpdate.prepare(archive: wrongZip, asset: wrongAsset, tag: "v1.7.0",
                architecture: "arm64", directory: directory.appendingPathComponent("wrong-prepared"))
        }
        try PropertyListSerialization.data(fromPropertyList: base, format: .xml, options: 0).write(to: info)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        try Data("broken executable".utf8).write(to: executable)
        let (broken, brokenAsset) = try archive("broken")
        #expect(throws: (any Error).self) {
            try BinaryUpdate.prepare(archive: broken, asset: brokenAsset, tag: "v1.7.0",
                architecture: "arm64", directory: directory.appendingPathComponent("broken-prepared"))
        }
        let link = app.appendingPathComponent("Contents/external-link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/tmp")
        let (linked, linkedAsset) = try archive("linked")
        #expect(throws: BinaryUpdate.Failure.unsafeArchive) {
            try BinaryUpdate.prepare(archive: linked, asset: linkedAsset, tag: "v1.7.0",
                architecture: "arm64", directory: directory.appendingPathComponent("linked-prepared"))
        }
    }
}
