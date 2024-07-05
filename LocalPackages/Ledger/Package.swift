// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ledger",
    platforms: [
        .macOS(.v12), .iOS(.v14)
    ],
    products: [
        .library(name: "TonTransport", targets: ["TonTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LedgerHQ/hw-transport-ios-ble.git", from: "1.0.0"),
        .package(url: "https://github.com/tonkeeper/ton-swift", from: "1.0.6"),
        .package(path: "../TKCryptoSwift"),
    ],
    targets: [
        .target(
            name: "TonTransport",
            dependencies: [
              .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "TKCryptoSwift", package: "TKCryptoSwift"),
                .product(name: "BleTransport", package: "hw-transport-ios-ble")
            ],
            path: "Sources/TonTransport"
        ),
    ]
)
