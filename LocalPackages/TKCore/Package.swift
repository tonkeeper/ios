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
        .package(path: "../TKAppInfo"),
        .package(path: "../KeeperCore"),
        .package(path: "../Ledger"),
        .package(path: "../TKKeychain"),
        .package(path: "../TKLogging"),
        .package(path: "../TKFeatureFlags"),
        // Imported directly by `TKCore`; previously satisfied transitively via static linking.
        .package(path: "../TKLocalize"),
        .package(path: "../TronSwift"),
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.36"),
        .package(url: "https://github.com/tonkeeper/ton-api-swift", exact: "0.8.0"),
        .package(url: "https://github.com/tonkeeper/hw-transport-ios-ble", from: "2.0.0"),
        .package(url: "https://github.com/attaswift/BigInt", exact: "5.3.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", .upToNextMajor(from: "0.6.1")),
    ],
    targets: [
        .target(
            name: "TKCore",
            dependencies: [
                .byName(name: "Kingfisher"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseInstallations", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                .product(name: "Aptabase", package: "aptabase-swift"),
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKAppInfo", package: "TKAppInfo"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "TonTransport", package: "Ledger"),
                .product(name: "TKKeychain", package: "TKKeychain"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "TonAPI", package: "ton-api-swift"),
                .product(name: "TronSwift", package: "TronSwift"),
                .product(name: "BleTransport", package: "hw-transport-ios-ble"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "AnyCodable", package: "AnyCodable"),
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
