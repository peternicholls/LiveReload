// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiveReloadCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "LiveReloadCore", targets: ["LiveReloadCore"])],
    targets: [
        .target(name: "LiveReloadCore"),
        .testTarget(
            name: "LiveReloadCoreTests",
            dependencies: ["LiveReloadCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
