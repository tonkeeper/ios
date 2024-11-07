// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "WalletCore",
  platforms: [
    .iOS(.v14)
  ],
  products: [
    .library(name: "WalletCore", type: .dynamic, targets: ["KeeperCore"])
  ],
  dependencies: [
    .package(path: "../TKLocalize"),
    .package(path: "../TKCryptoSwift"),
    .package(path: "../TKKeychain"),
    .package(path: "../Ledger"),
    .package(url: "https://github.com/tonkeeper/ton-swift", .upToNextMinor(from: "1.0.20")),
    .package(url: "https://github.com/tonkeeper/URKit", .upToNextMinor(from: "16.0.0")),
    .package(url: "https://github.com/tonkeeper/ton-api-swift", .upToNextMinor(from: "0.3.0")),
    .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "0.3.0")),
  ],
  targets: [
    .target(name: "CoreComponents",
            dependencies: [
              .product(name: "TonSwift", package: "ton-swift"),
              .product(name: "TKCryptoSwift", package: "TKCryptoSwift"),
              .product(name: "TKKeychain", package: "TKKeychain")
            ]),
    .testTarget(name: "CoreComponentsTests",
                dependencies: [
                  "CoreComponents"
                ]),
    .target(name: "KeeperCore",
            dependencies: [
              .product(name: "URKit", package: "URKit"),
              .product(name: "TKLocalize", package: "TKLocalize"),
//              .product(name: "TKKeychain", package: "TKKeychain"),
              .product(name: "TonTransport", package: "Ledger"),
              .product(name: "TonSwift", package: "ton-swift"),
              .product(name: "TonAPI", package: "ton-api-swift"),
              .product(name: "TonStreamingAPI", package: "ton-api-swift"),
              .target(name: "TonConnectAPI"),
              .target(name: "CoreComponents")
            ],
            path: "Sources/KeeperCore",
            resources: [
              .copy("PackageResources/DefaultRemoteConfiguration.json"),
              .copy("PackageResources/known_accounts.json")
            ]),
    .testTarget(name: "KeeperCoreTests",
                dependencies: [
                  "KeeperCore"
                ]),
    .target(name: "TonConnectAPI",
            dependencies: [
              .product(
                name: "OpenAPIRuntime",
                package: "swift-openapi-runtime"
              ),
            ],
            path: "Packages/TonConnectAPI",
            sources: ["Sources"]
           )
  ]
)
