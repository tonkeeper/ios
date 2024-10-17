// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TKUIKit",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "TKUIKit",
            targets: ["TKUIKit"]),
        .library(
            name: "TKUIKitDynamic",
            type: .dynamic,
            targets: ["TKUIKit"]
        )
    ],
    dependencies: [
      .package(path: "../TKLocalize"),
      .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
      .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "7.0.0")),
    ],
    targets: [
        .target(
            name: "TKUIKit",
            dependencies: [
              .product(name: "TKLocalize", package: "TKLocalize"),
              .product(name: "SnapKit-Dynamic", package: "SnapKit"),
              .byName(name: "Kingfisher"),
            ],
            path: "TKUIKit/Sources/TKUIKit",
            resources: [.process("Resources/Fonts")]
        )
    ]
)
