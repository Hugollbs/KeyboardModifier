// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyboardModifier",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "KeyboardModifier")
    ],
    swiftLanguageModes: [.v6]
)
