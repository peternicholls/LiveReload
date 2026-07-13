// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WebSocketPrototype",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "WebSocketPrototype")
    ]
)
