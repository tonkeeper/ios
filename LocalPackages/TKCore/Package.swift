// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKCore",
  platforms: [
    .macOS(.v13), .iOS(.v14)
  ],
  products: [
    .library(
      name: "TKCore",
      type: .dynamic,
      targets: ["TKCore"]),
  ],
  targets: [
    .target(
      name: "TKCore",
      resources: [.process("Resources")]),
    .testTarget(
      name: "TKCoreTests",
      dependencies: ["TKCore"]),
  ]
)
