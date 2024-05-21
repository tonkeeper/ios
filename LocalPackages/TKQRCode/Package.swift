// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKQRCode",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "TKQRCode",
      type: .dynamic,
      targets: ["TKQRCode"]),
  ],
  targets: [
    .target(
      name: "TKQRCode"),
  ]
)
