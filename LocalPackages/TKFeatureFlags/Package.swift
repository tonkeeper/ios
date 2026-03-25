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
        .package(path: "../TKLogging"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.8.0")),
    ],
    targets: [
        .target(
            name: "TKFeatureFlags",
            dependencies: [
                "TKAppInfo",
                "TKLogging",
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
