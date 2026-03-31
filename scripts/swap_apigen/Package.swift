// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "SwapAPIGen",
    platforms: [
        .macOS(.v12), .iOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", .upToNextMinor(from: "0.3.0")),
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "0.3.0")),
    ]
)
