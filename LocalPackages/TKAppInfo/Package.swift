// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKAppInfo",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "TKAppInfo",
            targets: ["TKAppInfo"]
        ),
    ],
    targets: [
        .target(
            name: "TKAppInfo",
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
