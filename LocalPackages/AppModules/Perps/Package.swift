// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Perps",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Perps",
            targets: ["Perps"]
        ),
    ],
    dependencies: [
        .package(path: "../AppUI"),
        .package(path: "../../LightweightCharts"),
        .package(path: "../../PerpsModels"),
        .package(path: "../../TKCoordinator"),
        .package(path: "../../TKLocalize"),
        .package(path: "../../TKLogging"),
        .package(path: "../../TKUIKit"),
    ],
    targets: [
        .target(
            name: "Perps",
            dependencies: [
                .product(name: "AppUI", package: "AppUI"),
                .product(name: "LightweightCharts", package: "LightweightCharts"),
                .product(name: "PerpsModels", package: "PerpsModels"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TKUIKit", package: "TKUIKit"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "PerpsTests",
            dependencies: ["Perps"],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
