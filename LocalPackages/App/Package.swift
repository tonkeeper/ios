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
        .package(url: "https://github.com/luximetr/AnyFormatKit.git", .upToNextMajor(from: "2.5.2")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.8.0")),
        // Imported directly by `App`; previously satisfied transitively via static linking.
        // Not imported by name: the diffable-datasource closures in RampPickerViewController
        // and TokenPickerViewController resolve `FixedWidthInteger.zero` to NumberKit's
        // extension, which is visible through DCBOR's re-exports. Real reference, so it has
        // to be linkable.
        // Only `AppTests` uses this — the Perps fixtures build ChainKit values directly.
        .package(url: "https://github.com/tonkeeper/chainkit-publishing", exact: "26.11.7"),
        .package(path: "../TKBase"),
        .package(path: "../AppModules/WalletExtensions"),
        .package(path: "../KeeperCore"),
        .package(path: "../TKCore"),
        .package(path: "../TKCoordinator"),
        .package(path: "../TKUIKit"),
        .package(path: "../TKScreenKit"),
        .package(path: "../AppModules/AppUI"),
        .package(path: "../AppModules/Perps"),
        .package(path: "../AppModules/MoonPay"),
        .package(path: "../AppModules/Stories"),
        .package(path: "../AppModules/SignRaw"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "AnyFormatKit", package: "AnyFormatKit"),
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKScreenKit", package: "TKScreenKit"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "TKBase", package: "TKBase"),
                .product(name: "TKStories", package: "Stories"),
                .product(name: "AppUI", package: "AppUI"),
                .product(name: "Perps", package: "Perps"),
                .product(name: "MoonPay", package: "MoonPay"),
                .product(name: "Stories", package: "Stories"),
                .product(name: "SignRaw", package: "SignRaw"),
                .product(name: "WalletExtensions", package: "WalletExtensions"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
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
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "TKBase", package: "TKBase"),
                .product(name: "TKTestSupport", package: "TKBase"),
                .product(name: "AppUI", package: "AppUI"),
                .product(name: "MoonPay", package: "MoonPay"),
                .product(name: "Perps", package: "Perps"),
                .product(name: "WalletExtensions", package: "WalletExtensions"),
                // Test-only: the Perps fixtures build ChainKit values directly. A test bundle
                // is not shipped, so linking ChainKit here does not put a second copy in the
                // app process — but `App` no longer provides it, so it must be declared.
                .product(name: "ChainKit", package: "chainkit-publishing"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
