// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TonTronKit",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "TonTronKit",
            targets: ["TonTronKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.32"),
        .package(url: "https://github.com/attaswift/BigInt", exact: Version(stringLiteral: "5.3.0")),
        .package(path: "../tron-swift"),
    ],
    targets: [
        .target(
            name: "TonTronKit",
            dependencies: [
                .product(name: "TronSwift", package: "tron-swift"),
                .product(name: "TronSwiftAPI", package: "tron-swift"),
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
