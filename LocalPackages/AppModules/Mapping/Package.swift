// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Mapping",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Mapping",
            targets: ["Mapping"]
        ),
    ],
    dependencies: [
        .package(path: "../../core-swift"),
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKLocalize"),
        .package(path: "../UIComponents"),
        .package(path: "../Resources"),
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Mapping",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "WalletCore", package: "core-swift"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "UIComponents", package: "UIComponents"),
                .product(name: "Resources", package: "Resources"),
                .product(name: "Core", package: "Core"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
