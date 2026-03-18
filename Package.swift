// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cute-hud",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "cute-hud",
            path: "Sources/cute-hud"
        ),
    ]
)
