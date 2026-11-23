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
        .package(path: "../../TKBase"),
        .package(path: "../../KeeperCore"),
        .package(path: "../WalletExtensions"),
    ],
    targets: [
        .target(
            name: "SignRaw",
            dependencies: [
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKCore", package: "TKCore"),
                .product(name: "TKBase", package: "TKBase"),
                .product(name: "KeeperCore", package: "KeeperCore"),
                .product(name: "WalletExtensions", package: "WalletExtensions"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
