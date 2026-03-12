// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKLottieWebView",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "TKLottieWebView",
            targets: ["TKLottieWebView"]
        ),
    ],
    dependencies: [
        .package(path: "../TKAppInfo"),
    ],
    targets: [
        .target(
            name: "TKLottieWebView",
            dependencies: [
                .product(name: "TKAppInfo", package: "TKAppInfo"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
