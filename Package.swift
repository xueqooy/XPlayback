// swift-tools-version:5.8
import PackageDescription

// TODO: Complete this when MobileVLCKit supports SPM

let package = Package(
    name: "XPlayback",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "Playback",
            targets: ["Playback"]
        ),
        .library(
            name: "PlaybackFoundation",
            targets: ["PlaybackFoundation"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/xueqooy/XUI", from: "1.0.0"),
        .package(url: "https://github.com/xueqooy/XKit", from: "1.0.0"),
        // MobileVLCKit: This is not support SPM yet
    ],
    targets: [
        .target(
            name: "Playback",
            dependencies: ["PlaybackFoundation", "XUI", "XKit"],
            path: "Source/Playback",
            resources: [
                .process("Images.xcassets"),
            ]
        ),
        .target(
            name: "PlaybackFoundation",
            dependencies: [
                "XKit", "MobileVLCKit"
            ],
            path: "Source/XPlayback"
        )
    ],
    swiftLanguageVersions: [.v5],
)
