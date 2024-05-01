// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TKUIKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "TKUIKit",
            targets: ["TKUIKit"]),
        .library(
          name: "TKScreenKIt",
          targets: ["TKScreenKit"])
    ],
    targets: [
        .target(
            name: "TKUIKit",
            dependencies: [],
            resources: [.process("Resources/Fonts")]),
        .target(
          name: "TKScreenKit",
          dependencies: [.target(name: "TKUIKit")]
        )
    ]
)
