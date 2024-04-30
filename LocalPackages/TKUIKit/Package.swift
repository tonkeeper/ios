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
      .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1"))
    ],
    targets: [
        .target(
            name: "TKUIKit",
            dependencies: [
              .product(name: "SnapKit-Dynamic", package: "SnapKit")
            ],
            path: "TKUIKit/Sources/TKUIKit",
            resources: [.process("Resources/Fonts")]
        )
    ]
)
