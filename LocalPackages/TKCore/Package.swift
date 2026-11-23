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
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.8.0")),
        .package(path: "../TKUIKit"),
        .package(path: "../TKBase"),
        .package(path: "../KeeperCore"),
    ],
    targets: [
        .target(
            name: "TKCore",
            dependencies: [
                "TKServices",
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "TKBase", package: "TKBase"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TKServices",
            dependencies: [
                .product(name: "FirebaseAnalyticsCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseInstallations", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKBase", package: "TKBase"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
            ],
            resources: [.process("Resources")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TKCoreTests",
            dependencies: ["TKCore", "TKServices"],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
