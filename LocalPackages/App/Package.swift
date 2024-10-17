// swift-tools-version: 5.8

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
    .package(url: "https://github.com/aptabase/aptabase-swift.git", .upToNextMajor(from: "0.3.9")),
    .package(url: "https://github.com/luximetr/AnyFormatKit.git", .upToNextMajor(from: "2.5.2")),
    .package(path: "../core-swift"),
    .package(path: "../TKCore"),
    .package(path: "../TKCoordinator"),
    .package(path: "../TKUIKit"),
    .package(path: "../TKScreenKit"),
    .package(path: "../TKStories")
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        .product(name: "Aptabase", package: "aptabase-swift"),
        .product(name: "AnyFormatKit", package: "AnyFormatKit"),
        .product(name: "TKUIKitDynamic", package: "TKUIKit"),
        .product(name: "TKScreenKit", package: "TKScreenKit"),
        .product(name: "TKCoordinator", package: "TKCoordinator"),
        .product(name: "TKCore", package: "TKCore"),
        .product(name: "WalletCore", package: "core-swift"),
        .product(name: "TKStories", package: "TKStories")
      ],
      resources: [.process("Resources")]
    )
  ]
)
