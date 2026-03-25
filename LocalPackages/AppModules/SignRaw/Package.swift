// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SignRaw",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SignRaw",
            targets: ["SignRaw"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKCore"),
        .package(path: "../../TKCoordinator"),
        .package(path: "../../TKFeatureFlags"),
        .package(path: "../../TKAppInfo"),
        .package(path: "../../core-swift"),
        .package(path: "../WalletExtensions"),
        .package(path: "../Mapping"),
    ],
    targets: [
        .target(
            name: "SignRaw",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKFeatureFlags", package: "TKFeatureFlags"),
                .product(name: "TKAppInfo", package: "TKAppInfo"),
                .product(name: "WalletCore", package: "core-swift"),
                .product(name: "WalletExtensions", package: "WalletExtensions"),
                .product(name: "Mapping", package: "Mapping"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
