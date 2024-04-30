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
    .package(url: "https://github.com/danielgindi/Charts", .upToNextMajor(from: "5.0.0")),
    .package(path: "../TKUIKit")
  ],
  targets: [
    .target(
      name: "TKChart",
      dependencies: [
        .product(name: "TKUIKitDynamic", package: "TKUIKit"),
        .product(name: "DGCharts", package: "Charts")
      ]),
    .testTarget(
            name: "TKChartTests",
            dependencies: ["TKChart"]),
  ]
)
