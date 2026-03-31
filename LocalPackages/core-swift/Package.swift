// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WalletCore",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "WalletCore", targets: ["KeeperCore"]),
    ],
    dependencies: [
        .package(path: "../TKLocalize"),
        .package(path: "../TKKeychain"),
        .package(path: "../Ledger"),
        .package(path: "../TKLogging"),
        .package(path: "../tron-swift"),
        .package(path: "../TKFeatureFlags"),
        .package(url: "https://github.com/ton-connect/kit-ios.git", exact: "0.3.2"),
        .package(url: "https://github.com/tonkeeper/CryptoSwift", revision: "1d31a1ffb6043655f3faba9d160db67b2e547e49"),
        .package(url: "https://github.com/tonkeeper/PunycodeSwift", revision: "30a462bdb4398ea835a3585472229e0d74b36ba5"),
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.32"),
        .package(url: "https://github.com/tonkeeper/URKit", .upToNextMinor(from: "16.0.0")),
        .package(url: "https://github.com/tonkeeper/ton-api-swift", exact: "0.6.0"),
        .package(url: "https://github.com/tonkeeper/battery-api-swift", .upToNextMinor(from: "3.0.0")),
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "0.3.0")),
    ],
    targets: [
        .target(
            name: "CoreComponents",
            dependencies: [
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "TKKeychain", package: "TKKeychain"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "CoreComponentsTests",
            dependencies: [
                "CoreComponents",
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "KeeperCore",
            dependencies: [
                .product(name: "URKit", package: "URKit"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TKKeychain", package: "TKKeychain"),
                .product(name: "TonTransport", package: "Ledger"),
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "TonAPI", package: "ton-api-swift"),
                .product(name: "TKBatteryAPI", package: "battery-api-swift"),
                .product(name: "TonStreamingAPI", package: "ton-api-swift"),
                .product(name: "TronSwift", package: "tron-swift"),
                .product(name: "TronSwiftAPI", package: "tron-swift"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "Punycode", package: "PunycodeSwift"),
                .target(name: "TonConnectAPI"),
                .target(name: "SwapAPI"),
                .target(name: "CoreComponents"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TONWalletKit", package: "kit-ios"),
            ],
            path: "Sources/KeeperCore",
            resources: [
                .copy("PackageResources/DefaultRemoteConfiguration.json"),
                .copy("PackageResources/known_accounts.json"),
            ]
        ),
        .testTarget(
            name: "KeeperCoreTests",
            dependencies: [
                "KeeperCore",
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TonConnectAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/TonConnectAPI",
            sources: ["Sources"],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "SwapAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/SwapAPI",
            sources: ["Sources"],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "WalletCoreTests",
            dependencies: [
                "KeeperCore",
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
