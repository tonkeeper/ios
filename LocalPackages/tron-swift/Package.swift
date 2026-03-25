// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TronSwift",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "TronSwift",
            targets: ["TronSwift"]
        ),
        .library(
            name: "TronSwiftAPI",
            targets: ["TronSwiftAPI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tonkeeper/swift-secp256k1", revision: "6c50e65ec9959d9ab0039df9ffc31707ad19c01b"),
        .package(url: "https://github.com/tonkeeper/CryptoSwift", revision: "1d31a1ffb6043655f3faba9d160db67b2e547e49"),
        .package(url: "https://github.com/attaswift/BigInt", exact: "5.3.0"),
        .package(path: "../TKLogging"),
    ],
    targets: [
        .target(
            name: "TronSwiftAPI",
            dependencies: [
                .byName(name: "TronSwift"),
                .product(name: "TKLogging", package: "TKLogging"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TronSwift",
            dependencies: [
                .product(name: "secp256k1", package: "swift-secp256k1"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "TKLogging", package: "TKLogging"),
                .byName(name: "TKCryptoKit"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TronSwift-Tests",
            dependencies: [.byName(name: "TronSwift")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TKCryptoKit",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TKCryptoKit-Tests",
            dependencies: [.byName(name: "TKCryptoKit")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
