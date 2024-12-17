// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Resources",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "Resources",
      targets: ["Resources"]),
  ],
  targets: [
    .target(
      name: "Resources",
      resources: [.process("Assets")])
  ]
)
