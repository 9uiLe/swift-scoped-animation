// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ScopedAnimation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "ScopedAnimation",
            targets: ["ScopedAnimation"]
        )
    ],
    targets: [
        .target(name: "ScopedAnimation"),
        .testTarget(
            name: "ScopedAnimationTests",
            dependencies: ["ScopedAnimation"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
