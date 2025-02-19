// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKAppInfo",
  platforms: [.iOS(.v14), .macOS(.v11)],
  products: [
    .library(
      name: "TKAppInfo",
      targets: ["TKAppInfo"]),
  ],
  targets: [
    .target(
      name: "TKAppInfo"
      )
  ]
)
