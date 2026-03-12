// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKFeatureFlags",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "TKFeatureFlags",
            targets: ["TKFeatureFlags"]
        ),
    ],
    dependencies: [
        .package(path: "../TKAppInfo"),
    ],
    targets: [
        .target(
            name: "TKFeatureFlags",
            dependencies: [
                "TKAppInfo",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
