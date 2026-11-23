// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WidgetUI",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "WidgetUI",
            targets: ["WidgetUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKBase"),
    ],
    targets: [
        .target(
            name: "WidgetUI",
            dependencies: [
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKBase", package: "TKBase"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
