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
  dependencies: [
    .package(url: "https://github.com/onevcat/Kingfisher.git", from: Version(7, 0, 0))
  ],
  targets: [
    .target(
      name: "TKCore",
      dependencies: [
        .byName(name: "Kingfisher")
      ],
      resources: [.process("Resources")]),
    .testTarget(
      name: "TKCoreTests",
      dependencies: ["TKCore"]),
  ]
)
