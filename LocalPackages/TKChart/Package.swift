// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKChart",
  platforms: [
    .macOS(.v12), .iOS(.v14)
  ],
  products: [
    .library(
      name: "TKChart",
      type: .dynamic,
      targets: ["TKChart"]),
  ],
  dependencies: [
    .package(url: "https://github.com/tonkeeper/tkuikit-ios.git", branch: "main"),
    .package(url: "https://github.com/danielgindi/Charts", .upToNextMajor(from: "5.0.0"))
  ],
  targets: [
    .target(
      name: "TKChart",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "DGCharts", package: "Charts")
      ]),
    .testTarget(
            name: "TKChartTests",
            dependencies: ["TKChart"]),
  ]
)
