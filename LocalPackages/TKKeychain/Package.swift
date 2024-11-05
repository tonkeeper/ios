// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKKeychain",
  platforms: [
    .iOS(.v14), .macOS(.v11)
  ],
  products: [
    .library(
      name: "TKKeychain",
      type: .dynamic,
      targets: ["TKKeychain"]),
  ],
  targets: [
    .target(
      name: "TKKeychain"
    )
  ]
)
