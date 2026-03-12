// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ledger",
    platforms: [
        .macOS(.v12), .iOS(.v15),
    ],
    products: [
        .library(name: "TonTransport", targets: ["TonTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tonkeeper/hw-transport-ios-ble", from: "2.0.0"),
        .package(url: "https://github.com/tonkeeper/ton-swift", revision: "991959e784ce55b65f5a6f66647d149af6eaf362"),
        .package(url: "https://github.com/tonkeeper/CryptoSwift", revision: "1d31a1ffb6043655f3faba9d160db67b2e547e49"),
    ],
    targets: [
        .target(
            name: "TonTransport",
            dependencies: [
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "BleTransport", package: "hw-transport-ios-ble"),
            ],
            path: "Sources/TonTransport",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
