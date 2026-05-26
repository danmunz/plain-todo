// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Plain",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlainCore",
            targets: ["PlainCore"]
        ),
        .executable(
            name: "PlainApp",
            targets: ["PlainApp"]
        )
    ],
    targets: [
        .target(
            name: "PlainCore"
        ),
        .executableTarget(
            name: "PlainApp",
            dependencies: ["PlainCore"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "PlainCoreTests",
            dependencies: ["PlainCore"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)