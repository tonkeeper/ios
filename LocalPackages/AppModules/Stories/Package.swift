// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Stories",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Stories",
            targets: ["Stories"]
        ),
        // The presentation layer stays a separate, KeeperCore-free target so it can be
        // previewed and reused without the wallet domain.
        .library(
            name: "TKStories",
            targets: ["TKStories"]
        ),
    ],
    dependencies: [
        .package(path: "../../KeeperCore"),
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKFeatureFlags"),
        .package(path: "../../TKCore"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
    ],
    targets: [
        .target(
            name: "TKStories",
            dependencies: [
                .product(name: "SnapKit-Dynamic", package: "SnapKit"),
                .product(name: "TKUIKit", package: "TKUIKit"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "Stories",
            dependencies: [
                .target(name: "TKStories"),
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "KeeperCoreComponents", package: "KeeperCore"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
