// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ExtraDock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ExtraDock", targets: ["ExtraDock"])
    ],
    targets: [
        // All app logic and UI lives in the library so it can be unit tested.
        .target(
            name: "ExtraDockKit",
            path: "Sources/ExtraDockKit"
        ),
        // Thin executable: just boots NSApplication with the AppDelegate.
        .executableTarget(
            name: "ExtraDock",
            dependencies: ["ExtraDockKit"],
            path: "Sources/ExtraDock"
        ),
        .testTarget(
            name: "ExtraDockKitTests",
            dependencies: ["ExtraDockKit"],
            path: "Tests/ExtraDockKitTests"
        )
    ]
)
