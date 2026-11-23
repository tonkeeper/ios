// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TKScreenKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "TKScreenKit",
            targets: ["TKScreenKit"]
        ),
    ],
    dependencies: [
        .package(path: "../TKUIKit"),
        .package(path: "../TKBase"),
    ],
    targets: [
        .target(
            name: "TKScreenKit",
            dependencies: [
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKBase", package: "TKBase"),
            ],
            path: "TKScreenKit/Sources/TKScreenKit",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
