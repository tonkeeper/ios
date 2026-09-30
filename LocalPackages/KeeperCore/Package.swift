// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KeeperCore",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // Dynamic so the wallet stack — ChainKit, yttrium, TonAPI, secp256k1,
        // the OpenAPI clients — is embedded once in the app and shared with
        // `TonkeeperWidgetExtension` / `TonkeeperIntents` over
        // `@executable_path/../../Frameworks`, instead of being statically linked into all
        // three binaries. Statically it cost ~35 MB per binary.
        //
        // Unlike `TKUIKit`, this cannot break SwiftUI Previews: previewable targets are not
        // allowed to depend on `KeeperCore` at all (AGENTS.md).
        //
        // Building a product dynamically makes SwiftPM build this package's whole transitive
        // graph as frameworks, and a framework links only what its own manifest declares — so
        // every dependency below has to be spelled out even where static linking used to
        // supply it for free.
        .library(name: "KeeperCore", type: .dynamic, targets: ["KeeperCore"]),
        // `App` and `Stories` import these directly, so they need to be products rather than
        // internal targets reached only through `KeeperCore`.
        .library(name: "KeeperCoreComponents", targets: ["KeeperCoreComponents"]),
        .library(name: "KeeperCoreSensitive", targets: ["KeeperCoreSensitive"]),
    ],
    dependencies: [
        .package(path: "../TKLocalize"),
        .package(path: "../TKKeychain"),
        .package(path: "../Ledger"),
        .package(path: "../TKLogging"),
        .package(path: "../TronSwift"),
        .package(path: "../TKFeatureFlags"),
        .package(path: "../TKAppInfo"),
        .package(url: "https://github.com/tonkeeper/URKit", .upToNextMinor(from: "16.0.1")),
        // Imported directly by the targets below; previously satisfied transitively because
        // everything ended up statically linked into the app binary. Versions mirror what
        // ton-swift already resolves to, so the dependency graph is unchanged.
        .package(url: "https://github.com/attaswift/BigInt", exact: "5.3.0"),
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/jedisct1/swift-sodium", exact: "0.9.1"),
        .package(url: "https://github.com/apple/swift-http-types", .upToNextMajor(from: "1.0.0")),
        // Not imported by name: `KeeperCore` resolves `FixedWidthInteger.zero` to NumberKit's
        // extension, which is visible through DCBOR's re-exports. The reference is real, so
        // the symbol has to be linkable.
        .package(url: "https://github.com/objecthub/swift-numberkit.git", .upToNextMajor(from: "2.6.0")),
        .package(url: "https://github.com/tonkeeper/CryptoSwift", revision: "1d31a1ffb6043655f3faba9d160db67b2e547e49"),
        .package(url: "https://github.com/tonkeeper/PunycodeSwift", exact: "3.0.1"),
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.36"),
        .package(url: "https://github.com/tonkeeper/ton-api-swift", exact: "0.8.0"),
        .package(url: "https://github.com/tonkeeper/battery-api-swift", exact: "4.0.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "0.3.0")),
        .package(url: "https://github.com/tonkeeper/chainkit-swift", exact: "0.1.28"),
        .package(url: "https://github.com/reown-com/reown-swift.git", exact: "2.2.9"),
        .package(url: "https://github.com/Flight-School/AnyCodable", .upToNextMajor(from: "0.6.1")),
        .package(url: "https://github.com/centrifugal/centrifuge-swift", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "KeeperCoreComponents",
            dependencies: [
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "TKKeychain", package: "TKKeychain"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "KeeperCoreComponentsTests",
            dependencies: [
                "KeeperCoreComponents",
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "KeeperCoreSensitive",
            dependencies: [
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "Sodium", package: "swift-sodium"),
                .target(name: "KeeperCoreComponents"),
            ],
            path: "Sources/KeeperCoreSensitive",
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
                .product(name: "TonStreamingAPIV2", package: "ton-api-swift"),
                .product(name: "TronSwift", package: "TronSwift"),
                .product(name: "TronSwiftAPI", package: "TronSwift"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "Punycode", package: "PunycodeSwift"),
                .product(name: "ChainKit", package: "chainkit-swift"),
                // The `ChainKit` product already carries WalletCore via `ChainKitSupport`, which
                // is enough for anything depending on that product — `KeeperCore.framework`
                // links without this. The test targets below depend on the `KeeperCore` *target*
                // by name, so they get ChainKit's static archive without that product grouping
                // and fail on undefined `_TWAnyAddress*`; this puts WalletCore on their link
                // line. `ChainKit` is a `.binaryTarget` and so cannot declare it itself.
                .product(name: "WalletCore", package: "chainkit-swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "ReownWalletKit", package: "reown-swift"),
                .product(name: "ReownRouter", package: "reown-swift"),
                .product(name: "AnyCodable", package: "AnyCodable"),
                .target(name: "TonConnectAPI"),
                .target(name: "SwapAPI"),
                .target(name: "MultichainAPI"),
                .target(name: "TKTradingAPI"),
                .target(name: "TKPerpsAPI"),
                .target(name: "TKKandelabrAPI"),
                .target(name: "TKTonkeeperAPI"),
                .target(name: "KeeperCoreComponents"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TKAppInfo", package: "TKAppInfo"),
                .product(name: "TKCryptoKit", package: "TronSwift"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "Sodium", package: "swift-sodium"),
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "EventSource", package: "ton-api-swift"),
                .product(name: "StreamURLSessionTransport", package: "ton-api-swift"),
                .product(name: "NumberKit", package: "swift-numberkit"),
                .product(name: "SwiftCentrifuge", package: "centrifuge-swift"),
                .target(name: "KeeperCoreSensitive"),
            ],
            path: "Sources/KeeperCore",
            resources: [
                .copy("PackageResources/DefaultBootConfiguration.json"),
                .copy("PackageResources/known_accounts.json"),
            ]
        ),
        .testTarget(
            name: "KeeperCoreTests",
            dependencies: [
                "KeeperCore",
                "KeeperCoreComponents",
                "KeeperCoreSensitive",
                "MultichainAPI",
                "SwapAPI",
                "TKKandelabrAPI",
                "TKPerpsAPI",
                .product(name: "AnyCodable", package: "AnyCodable"),
                .product(name: "TKLogging", package: "TKLogging"),
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
            sources: ["Sources"]
        ),
        .target(
            name: "MultichainAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/MultichainAPI",
            sources: ["Sources"]
        ),
        .target(
            name: "TKTradingAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/TKTradingAPI",
            sources: ["Sources"]
        ),
        .target(
            name: "TKTonkeeperAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/TKTonkeeperAPI",
            sources: ["Sources"],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TKPerpsAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/TKPerpsAPI",
            sources: ["Sources"],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TKKandelabrAPI",
            dependencies: [
                .product(
                    name: "OpenAPIRuntime",
                    package: "swift-openapi-runtime"
                ),
            ],
            path: "Packages/TKKandelabrAPI",
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
