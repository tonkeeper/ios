// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "signer-core",
    platforms: [
        .macOS(.v12), .iOS(.v14)
    ],
    products: [
        .library(
            name: "SignerCore",
            targets: ["SignerCore"]),
    ],
    dependencies: [
      .package(url: "https://github.com/tonkeeper/ton-swift", branch: "main"),
      .package(url: "https://github.com/tonkeeper/core-swift", branch: "develop")
    ],
    targets: [
        .target(
            name: "SignerCore",
        dependencies: [
          .product(name: "TonSwift", package: "ton-swift"),
          .product(name: "WalletCoreCore", package: "core-swift")
        ]),
        .testTarget(
            name: "SignerCoreTests",
            dependencies: ["SignerCore"]),
    ]
)
