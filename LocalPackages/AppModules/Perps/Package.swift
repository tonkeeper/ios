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
        .package(path: "../../TKBase"),
        .package(path: "../../TKCoordinator"),
        .package(path: "../../TKUIKit"),
    ],
    targets: [
        .target(
            name: "Perps",
            dependencies: [
                .product(name: "AppUI", package: "AppUI"),
                .product(name: "LightweightCharts", package: "LightweightCharts"),
                .product(name: "TKBase", package: "TKBase"),
                .product(name: "TKCoordinator", package: "TKCoordinator"),
                .product(name: "TKUIKit", package: "TKUIKit"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "PerpsTests",
            dependencies: [
                "Perps",
                .product(name: "TKTestSupport", package: "TKBase"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
