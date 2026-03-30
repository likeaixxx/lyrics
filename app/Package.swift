// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lyrics",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Lyrics", targets: ["Lyrics"]),
    ],
    dependencies: [
        // Add dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "Lyrics",
            dependencies: [],
            path: "Lyrics",
            exclude: [
                "Info.plist",
                "Lyrics.entitlements",
                "Preview Content",
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
    ]
)
