// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Core",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "Core",
      targets: ["Core"]),
  ],
  targets: [
    .target(
      name: "Core"
      )
  ]
)
