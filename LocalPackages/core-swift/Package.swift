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
    .package(path: "../Ledger"),
    .package(url: "https://github.com/tonkeeper/ton-swift", .upToNextMinor(from: "1.0.18")),
    .package(url: "https://github.com/tonkeeper/ton-api-swift", .upToNextMinor(from: "0.3.0")),
    .package(url: "https://github.com/tonkeeper/battery-api-swift", .upToNextMinor(from: "2.0.0")),
    .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "0.3.0")),
  ],
  targets: [
    .target(name: "CoreComponents",
            dependencies: [
              .product(name: "TonSwift", package: "ton-swift"),
              .product(name: "TKCryptoSwift", package: "TKCryptoSwift"),
            ]),
    .testTarget(name: "CoreComponentsTests",
                dependencies: [
                  "CoreComponents"
                ]),
    .target(name: "KeeperCore",
            dependencies: [
              .product(name: "TKLocalize", package: "TKLocalize"),
              .product(name: "TonTransport", package: "Ledger"),
              .product(name: "TonSwift", package: "ton-swift"),
              .product(name: "TonAPI", package: "ton-api-swift"),
              .product(name: "TKBatteryAPI", package: "battery-api-swift"),
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
