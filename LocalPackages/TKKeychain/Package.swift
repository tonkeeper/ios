// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKKeychain",
    platforms: [
        .iOS(.v15), .macOS(.v11),
    ],
    products: [
        .library(
            name: "TKKeychain",
            targets: ["TKKeychain"]
        ),
    ],
    dependencies: [
        .package(path: "../TKLogging"),
    ],
    targets: [
        .target(
            name: "TKKeychain",
            dependencies: [
                .product(name: "TKLogging", package: "TKLogging"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
