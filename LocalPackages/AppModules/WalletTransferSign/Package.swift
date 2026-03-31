// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WalletTransferSign",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "WalletTransferSign",
            targets: ["WalletTransferSign"]
        ),
    ],
    dependencies: [
        .package(path: "../../core-swift"),
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKCoordinator"),
        .package(path: "../../TKLocalize"),
        .package(path: "../../TKCore"),
    ],
    targets: [
        .target(
            name: "WalletTransferSign",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "WalletCore", package: "core-swift"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TKCore", package: "TKCore"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
