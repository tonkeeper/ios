// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TKScreenKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "TKScreenKit",
            targets: ["TKScreenKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
        .package(path: "../TKUIKit"),
        .package(path: "../TKLocalize"),
    ],
    targets: [
        .target(
            name: "TKScreenKit",
            dependencies: [
                .product(name: "SnapKit-Dynamic", package: "SnapKit"),
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
                .product(name: "TKLocalize", package: "TKLocalize"),
            ],
            path: "TKScreenKit/Sources/TKScreenKit",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
