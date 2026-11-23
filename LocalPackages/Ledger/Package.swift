// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ledger",
    platforms: [
        .macOS(.v12), .iOS(.v15),
    ],
    products: [
        .library(name: "LedgerKit", targets: ["LedgerKit"]),
        .library(name: "TonTransport", targets: ["TonTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.37"),
        // `TonTransport` imports BigInt directly; it used to resolve only because a static
        // build let the final binary supply the symbols.
        .package(url: "https://github.com/attaswift/BigInt", exact: "5.3.0"),
        .package(path: "../TKBase"),
    ],
    targets: [
        .target(
            name: "LedgerKit",
            path: "Sources/LedgerKit",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TonTransport",
            dependencies: [
                "LedgerKit",
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "BigInt", package: "BigInt"),
            ],
            path: "Sources/TonTransport",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TonTransportTests",
            dependencies: [
                "LedgerKit",
                "TonTransport",
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "TKTestSupport", package: "TKBase"),
            ],
            path: "Tests/TonTransportTests",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
