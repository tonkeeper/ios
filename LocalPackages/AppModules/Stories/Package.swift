// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Stories",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "Stories",
      targets: ["Stories"]),
  ],
  dependencies: [
    .package(path: "../../core-swift"),
    .package(path: "../../TKUIKit"),
    .package(path: "../../TKStories")
  ],
  targets: [
    .target(
      name: "Stories",
      dependencies: [
        .product(name: "TKUIKitDynamic", package: "TKUIKit"),
        .product(name: "TKStories", package: "TKStories"),
        .product(name: "WalletCore", package: "core-swift")
      ])
  ]
)
