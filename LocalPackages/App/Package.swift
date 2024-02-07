// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "App",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "App",
      targets: ["App"]),
  ],
  dependencies: [
    .package(url: "https://github.com/tonkeeper/tkuikit-ios.git", branch: "main"),
    .package(url: "https://github.com/tonkeeper/core-swift", branch: "feature/refact"),
    .package(path: "../TKCore"),
    .package(path: "../TKCoordinator")
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKScreenKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator"),
        .product(name: "TKCore", package: "TKCore"),
        .product(name: "WalletCore", package: "core-swift"),
      ],
      resources: [.process("Resources")]
    )
  ]
)
