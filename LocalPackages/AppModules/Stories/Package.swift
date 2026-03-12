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
    ],
    dependencies: [
        .package(path: "../../core-swift"),
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKStories"),
        .package(path: "../../TKFeatureFlags"),
        .package(path: "../../TKCore"),
    ],
    targets: [
        .target(
            name: "Stories",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "TKStories", package: "TKStories"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "WalletCore", package: "core-swift"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
