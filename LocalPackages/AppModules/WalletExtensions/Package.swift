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
        .package(path: "../../KeeperCore"),
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKBase"),
    ],
    targets: [
        .target(
            name: "WalletExtensions",
            dependencies: [
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "TKBase", package: "TKBase"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
