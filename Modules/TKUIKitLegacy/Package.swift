// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TKUIKitLegacy",
    platforms: [
        .macOS(.v12), .iOS(.v13)
    ],
    products: [
        .library(
            name: "TKUIKitLegacy",
            type: .dynamic,
            targets: ["TKUIKitLegacy"]),
    ],
    targets: [
        .target(
            name: "TKUIKitLegacy"),
    ]
)
