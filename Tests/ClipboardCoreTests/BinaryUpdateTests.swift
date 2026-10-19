import Foundation
import Testing
@testable import ClipboardCore

struct BinaryUpdateTests {
    private let hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    private func asset(url: String? = nil, digest: String? = nil, size: Int64 = 3) -> BinaryReleaseAsset {
        BinaryReleaseAsset(name: "ClipboardAssistant-1.7.0-arm64.zip",
            url: URL(string: url ?? "https://github.com/mauringo/clipkeep-macos/releases/download/v1.7.0/ClipboardAssistant-1.7.0-arm64.zip")!,
            digest: digest ?? "sha256:" + hash, size: size)
    }

    @Test func assetMustMatchStableVersionArchitectureOriginPathAndDigest() {
        #expect(asset().isValid(for: "v1.7.0", architecture: "arm64"))
        #expect(!asset().isValid(for: "v1.7.0", architecture: "x86_64"))
        #expect(!asset().isValid(for: "v1.7.1", architecture: "arm64"))
        #expect(!asset().isValid(for: "v1.7.0-beta", architecture: "arm64"))
        #expect(!asset(url: "https://example.com/update.zip").isValid(for: "v1.7.0", architecture: "arm64"))
        #expect(!asset(digest: "sha256:wrong").isValid(for: "v1.7.0", architecture: "arm64"))
        #expect(!asset(size: 300_000_000).isValid(for: "v1.7.0", architecture: "arm64"))
    }

    @Test func checksumAndByteCountMustBothMatch() throws {
        try BinaryUpdate.verify(Data("abc".utf8), asset: asset())
        #expect(throws: (any Error).self) { try BinaryUpdate.verify(Data("abd".utf8), asset: asset()) }
        #expect(throws: (any Error).self) { try BinaryUpdate.verify(Data("abc".utf8), asset: asset(size: 4)) }
    }

    @Test func archivesMustContainOnlyTheExpectedAppWithoutTraversal() throws {
        try BinaryUpdate.validateArchivePaths(["Clipboard Assistant.app/", "Clipboard Assistant.app/Contents/Info.plist"])
        for paths in [[String](), ["/Clipboard Assistant.app/file"], ["Clipboard Assistant.app/../../outside"], ["another.app/file"], ["__MACOSX/file"]] {
            #expect(throws: (any Error).self) { try BinaryUpdate.validateArchivePaths(paths) }
        }
    }
}
