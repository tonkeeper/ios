// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "TKStories",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "TKStories",
      targets: ["TKStories"]),
  ],
  dependencies: [
    .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
    .package(path: "../TKUIKit"),
  ],
  targets: [
    .target(
      name: "TKStories",
      dependencies: [
        .product(name: "SnapKit-Dynamic", package: "SnapKit"),
        .product(name: "TKUIKitDynamic", package: "TKUIKit")
      ])
  ]
)
