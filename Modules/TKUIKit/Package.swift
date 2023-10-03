// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TKUIKit",
    platforms: [
        .macOS(.v12), .iOS(.v13)
    ],
    products: [
        .library(
            name: "TKUIKit",
            type: .dynamic,
            targets: ["TKUIKit"]),
    ],
    targets: [
        .target(
            name: "TKUIKit"),
    ]
)
