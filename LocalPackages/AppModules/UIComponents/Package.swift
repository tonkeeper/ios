// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "UIComponents",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "UIComponents",
      targets: ["UIComponents"]),
  ],
  dependencies: [
    .package(path: "../../TKUIKit")
  ],
  targets: [
    .target(
      name: "UIComponents",
      dependencies: [
        .product(name: "TKUIKitDynamic", package: "TKUIKit")
      ])
  ]
)
