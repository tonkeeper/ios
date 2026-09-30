// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "App",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "App",
            targets: ["App"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/aptabase/aptabase-swift.git", .upToNextMajor(from: "0.3.9")),
        .package(url: "https://github.com/luximetr/AnyFormatKit.git", .upToNextMajor(from: "2.5.2")),
        .package(url: "https://github.com/airbnb/lottie-spm.git", exact: "4.6.0"),
        .package(url: "https://github.com/tonkeeper/ton-swift", exact: "1.0.36"),
        // Imported directly by `App`; previously satisfied transitively via static linking.
        .package(url: "https://github.com/attaswift/BigInt", exact: "5.3.0"),
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/tonkeeper/CryptoSwift", revision: "1d31a1ffb6043655f3faba9d160db67b2e547e49"),
        .package(url: "https://github.com/tonkeeper/hw-transport-ios-ble", from: "2.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
        // Not imported by name: the diffable-datasource closures in RampPickerViewController
        // and TokenPickerViewController resolve `FixedWidthInteger.zero` to NumberKit's
        // extension, which is visible through DCBOR's re-exports. Real reference, so it has
        // to be linkable.
        .package(url: "https://github.com/objecthub/swift-numberkit.git", .upToNextMajor(from: "2.6.0")),
        .package(url: "https://github.com/tonkeeper/URKit", .upToNextMinor(from: "16.0.1")),
        // Only `AppTests` uses this — the Perps fixtures build ChainKit values directly.
        .package(url: "https://github.com/tonkeeper/chainkit-swift", exact: "0.1.28"),
        .package(path: "../Ledger"),
        .package(path: "../TronSwift"),
        .package(path: "../TKKeychain"),
        .package(path: "../AppModules/WalletExtensions"),
        .package(path: "../LightweightCharts"),
        .package(path: "../KeeperCore"),
        .package(path: "../TKCore"),
        .package(path: "../TKCoordinator"),
        .package(path: "../TKUIKit"),
        .package(path: "../TKLocalize"),
        .package(path: "../TKScreenKit"),
        .package(path: "../TKFeatureFlags"),
        .package(path: "../TKAppInfo"),
        .package(path: "../TKLogging"),
        .package(path: "../AppModules/AppUI"),
        .package(path: "../AppModules/Stories"),
        .package(path: "../AppModules/SignRaw"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Aptabase", package: "aptabase-swift"),
                .product(name: "AnyFormatKit", package: "AnyFormatKit"),
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "LightweightCharts", package: "LightweightCharts"),
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKScreenKit", package: "TKScreenKit"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TKStories", package: "Stories"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "AppUI", package: "AppUI"),
                .product(name: "Stories", package: "Stories"),
                .product(name: "SignRaw", package: "SignRaw"),
                .product(name: "TKAppInfo", package: "TKAppInfo"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "URKit", package: "URKit"),
                .product(name: "BleTransport", package: "hw-transport-ios-ble"),
                .product(name: "TonTransport", package: "Ledger"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit-Dynamic", package: "SnapKit"),
                .product(name: "TronSwift", package: "TronSwift"),
                .product(name: "TKCryptoKit", package: "TronSwift"),
                .product(name: "TKKeychain", package: "TKKeychain"),
                .product(name: "WalletExtensions", package: "WalletExtensions"),
                .product(name: "KeeperCoreComponents", package: "KeeperCore"),
                .product(name: "KeeperCoreSensitive", package: "KeeperCore"),
                .product(name: "NumberKit", package: "swift-numberkit"),
            ],
            resources: [.process("Resources")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "AppUI", package: "AppUI"),
                .product(name: "TonSwift", package: "ton-swift"),
                // Test-only: the Perps fixtures build ChainKit values directly. A test bundle
                // is not shipped, so linking ChainKit here does not put a second copy in the
                // app process — but `App` no longer provides it, so it must be declared.
                .product(name: "ChainKit", package: "chainkit-swift"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
