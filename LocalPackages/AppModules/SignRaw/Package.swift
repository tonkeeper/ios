// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SignRaw",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "SignRaw",
      targets: ["SignRaw"]),
  ],
  dependencies: [
    .package(path: "../../TKUIKit"),
    .package(path: "../../TKCore"),
    .package(path: "../TKCoordinator"),
    .package(path: "../../core-swift")
  ],
  targets: [
    .target(
      name: "SignRaw",
      dependencies: [
        .product(name: "TKUIKitDynamic", package: "TKUIKit"),
        .product(name: "TKCore", package: "TKCore"),
        .product(name: "TKCoordinator", package: "TKCoordinator"),
        .product(name: "WalletCore", package: "core-swift")
      ])
  ]
)
