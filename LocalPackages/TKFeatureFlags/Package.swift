// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKFeatureFlags",
  platforms: [.iOS(.v14), .macOS(.v11)],
  products: [
    .library(
      name: "TKFeatureFlags",
      targets: ["TKFeatureFlags"]),
  ],
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "11.0.0")),
  ],
  targets: [
    .target(
      name: "TKFeatureFlags",
    dependencies: [
      .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
    ]),
  ]
)
