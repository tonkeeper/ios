// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKCore",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "TKCore",
            targets: ["TKCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.8.0")),
        .package(url: "https://github.com/aptabase/aptabase-swift.git", .upToNextMajor(from: "0.3.9")),
        .package(path: "../TKUIKit"),
        .package(path: "../core-swift"),
        .package(path: "../Ledger"),
        .package(path: "../TKKeychain"),
        .package(path: "../TKLogging"),
        .package(path: "../TKFeatureFlags"),
    ],
    targets: [
        .target(
            name: "TKCore",
            dependencies: [
                .byName(name: "Kingfisher"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                .product(name: "Aptabase", package: "aptabase-swift"),
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "WalletCore", package: "core-swift"),
                .product(name: "TonTransport", package: "Ledger"),
                .product(name: "TKKeychain", package: "TKKeychain"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
            ],
            resources: [.process("Resources")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TKCoreTests",
            dependencies: ["TKCore"],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
