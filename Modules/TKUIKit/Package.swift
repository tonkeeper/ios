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
            targets: ["TKUIKit"]),
    ],
    targets: [
        .target(
            name: "TKUIKit"),
        .testTarget(
            name: "TKUIKitTests",
            dependencies: ["TKUIKit"]),
    ]
)
