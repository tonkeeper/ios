// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "DisconnectDappToast",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "DisconnectDappToast",
      targets: ["DisconnectDappToast"]),
  ],
  dependencies: [
    .package(path: "../../TKUIKit"),
  ],
  targets: [
    .target(
      name: "DisconnectDappToast",
      dependencies: [
        .product(name: "TKUIKitDynamic", package: "TKUIKit")
      ]),
  ]
)
