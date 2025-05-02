// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "TronSwift",
  platforms: [.iOS(.v14), .macOS(.v11)],
  products: [
    .library(
      name: "TronSwift",
      targets: ["TronSwift"]),
    .library(
      name: "TronSwiftAPI",
      targets: ["TronSwiftAPI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/tonkeeper/swift-secp256k1", revision: "6c50e65ec9959d9ab0039df9ffc31707ad19c01b"),
    .package(url: "https://github.com/tonkeeper/CryptoSwift", revision: "1d31a1ffb6043655f3faba9d160db67b2e547e49")
  ],
  targets: [
    .target(
      name: "TronSwiftAPI",
      dependencies: [
        .byName(name: "TronSwift")
      ]
    ),
    .target(
      name: "TronSwift",
      dependencies: [
        .product(name: "secp256k1", package: "swift-secp256k1"),
        .product(name: "CryptoSwift", package: "CryptoSwift"),
        .byName(name: "TKCryptoKit")
      ]
    ),
    .testTarget(
      name: "TronSwift-Tests",
      dependencies: [.byName(name: "TronSwift")]
    ),
    .target(
      name: "TKCryptoKit"
    ),
    .testTarget(
      name: "TKCryptoKit-Tests",
      dependencies: [.byName(name: "TKCryptoKit")]
    )
  ]
)
