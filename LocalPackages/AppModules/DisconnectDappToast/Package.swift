// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DisconnectDappToast",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "DisconnectDappToast",
            targets: ["DisconnectDappToast"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKLogging"),
    ],
    targets: [
        .target(
            name: "DisconnectDappToast",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "TKLogging", package: "TKLogging"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
