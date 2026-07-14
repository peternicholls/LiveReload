// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiveReloadCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LiveReloadCore", targets: ["LiveReloadCore"]),
        .executable(name: "LiveReloadBrowserHarness", targets: ["LiveReloadBrowserHarness"]),
        .executable(name: "LiveReloadIdleProbe", targets: ["LiveReloadIdleProbe"]),
    ],
    targets: [
        .target(name: "LiveReloadCore"),
        .executableTarget(
            name: "LiveReloadBrowserHarness",
            dependencies: ["LiveReloadCore"]
        ),
        .executableTarget(
            name: "LiveReloadIdleProbe",
            dependencies: ["LiveReloadCore"],
            path: "Tools/LiveReloadIdleProbe"
        ),
        .testTarget(
            name: "LiveReloadCoreTests",
            dependencies: ["LiveReloadCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
