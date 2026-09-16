// swift-tools-version: 5.7
//
// Host-side build tool only: the generated clients import swift-openapi-runtime,
// which KeeperCore declares. The generator version is exact because the generated
// sources are committed — a floating resolve made the output machine-dependent.

import PackageDescription

let package = Package(
    name: "APIGen",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "0.3.5"),
    ]
)
