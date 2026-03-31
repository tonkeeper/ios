// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WalletExtensions",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "WalletExtensions",
            targets: ["WalletExtensions"]
        ),
    ],
    dependencies: [
        .package(path: "../../core-swift"),
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKLocalize"),
    ],
    targets: [
        .target(
            name: "WalletExtensions",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "WalletCore", package: "core-swift"),
                .product(name: "TKLocalize", package: "TKLocalize"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
