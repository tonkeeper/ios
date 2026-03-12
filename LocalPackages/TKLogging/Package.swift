// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TKLogging",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "TKLogging",
            targets: ["TKLogging"]
        ),
    ],
    targets: [
        .target(
            name: "TKLogging"
        ),
    ]
)
