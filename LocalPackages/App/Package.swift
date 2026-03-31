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
        .package(path: "../core-swift"),
        .package(path: "../TKCore"),
        .package(path: "../TKCoordinator"),
        .package(path: "../TKUIKit"),
        .package(path: "../TKLocalize"),
        .package(path: "../TKScreenKit"),
        .package(path: "../TKStories"),
        .package(path: "../TKFeatureFlags"),
        .package(path: "../TKLottieWebView"),
        .package(path: "../TKAppInfo"),
        .package(path: "../TKChart"),
        .package(path: "../TKLogging"),
        .package(path: "../AppModules/Stories"),
        .package(path: "../AppModules/SignRaw"),
        .package(path: "../AppModules/DisconnectDappToast"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Aptabase", package: "aptabase-swift"),
                .product(name: "AnyFormatKit", package: "AnyFormatKit"),
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "TKScreenKit", package: "TKScreenKit"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "WalletCore", package: "core-swift"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TKStories", package: "TKStories"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "Stories", package: "Stories"),
                .product(name: "SignRaw", package: "SignRaw"),
                .product(name: "DisconnectDappToast", package: "DisconnectDappToast"),
                .product(name: "TKLottieWebView", package: "TKLottieWebView"),
                .product(name: "TKAppInfo", package: "TKAppInfo"),
                .product(name: "TKChart", package: "TKChart"),
                .product(name: "TKLogging", package: "TKLogging"),
            ],
            resources: [.process("Resources")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
