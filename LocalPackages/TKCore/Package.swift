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
    .package(url: "https://github.com/onevcat/Kingfisher.git", from: Version(7, 0, 0)),
    .package(url: "https://github.com/tonkeeper/core-swift", branch: "feature/refact"),
    .package(url: "https://github.com/tonkeeper/tkuikit-ios.git", branch: "main")
  ],
  targets: [
    .target(
      name: "TKCore",
      dependencies: [
        .byName(name: "Kingfisher"),
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "WalletCore", package: "core-swift"),
      ],
      resources: [.process("Resources")]),
    .testTarget(
      name: "TKCoreTests",
      dependencies: ["TKCore"]),
  ]
)
