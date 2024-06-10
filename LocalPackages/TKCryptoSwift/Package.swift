// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TKCryptoSwift",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "TKCryptoSwift",
            targets: ["CryptoSwift"]
        )
    ],
    targets: [
        .binaryTarget(name: "CryptoSwift", path: "TKCryptoSwift/CryptoSwift.xcframework"),
    ]
)
