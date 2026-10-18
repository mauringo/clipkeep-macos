// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardAssistant",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ClipboardAssistant", targets: ["ClipboardAssistant"])],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")],
    targets: [
        .target(name: "ClipboardCore", dependencies: [.product(name: "Yams", package: "Yams")]),
        .executableTarget(name: "ClipboardAssistant", dependencies: ["ClipboardCore"]),
        .testTarget(name: "ClipboardCoreTests", dependencies: ["ClipboardCore"])
    ],
    swiftLanguageModes: [.v5]
)
