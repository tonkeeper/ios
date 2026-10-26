// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MoonPay",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "MoonPay",
            targets: ["MoonPay"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKLogging"),
    ],
    targets: [
        .target(
            name: "MoonPay",
            dependencies: [
                .product(name: "TKLogging", package: "TKLogging"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "MoonPayTests",
            dependencies: ["MoonPay"],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
