// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKStories",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "TKStories",
            targets: ["TKStories"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
        .package(path: "../TKUIKit"),
    ],
    targets: [
        .target(
            name: "TKStories",
            dependencies: [
                .product(name: "SnapKit-Dynamic", package: "SnapKit"),
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
