// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TKChart",
  platforms: [
    .macOS(.v12), .iOS(.v13)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "TKChart",
      type: .dynamic,
      targets: ["TKChart"]),
  ],
  dependencies: [
    .package(path: "../TKUIKitLegacy"),
    .package(url: "https://github.com/danielgindi/Charts", .upToNextMajor(from: "5.0.0"))
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "TKChart",
      dependencies: [.product(name: "TKUIKitLegacy", package: "TKUIKitLegacy"),
                     .product(name: "DGCharts", package: "Charts")]),
    .testTarget(
            name: "TKChartTests",
            dependencies: ["TKChart"]),
  ]
)
