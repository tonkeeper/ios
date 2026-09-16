// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SignRaw",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SignRaw",
            targets: ["SignRaw"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKCore"),
        .package(path: "../../TKCoordinator"),
        .package(path: "../../TKFeatureFlags"),
        .package(path: "../../KeeperCore"),
        .package(path: "../WalletExtensions"),
        .package(path: "../../TKLocalize"),
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.36"),
        .package(url: "https://github.com/attaswift/BigInt", exact: "5.3.0"),
    ],
    targets: [
        .target(
            name: "SignRaw",
            dependencies: [
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "WalletExtensions", package: "WalletExtensions"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "BigInt", package: "BigInt"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
