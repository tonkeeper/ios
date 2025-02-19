// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKLottieWebView",
  platforms: [.iOS(.v14), .macOS(.v11)],
  products: [
    .library(
      name: "TKLottieWebView",
      targets: ["TKLottieWebView"]),
  ],
  dependencies: [
    .package(path: "../TKAppInfo")
  ],
  targets: [
    .target(
      name: "TKLottieWebView",
      dependencies: [
        .product(name: "TKAppInfo", package: "TKAppInfo")
      ],
      resources: [.process("Resources")]),
  ]
)
