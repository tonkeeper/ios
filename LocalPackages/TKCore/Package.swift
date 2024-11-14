// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TKCore",
  platforms: [
    .iOS(.v14)
  ],
  products: [
    .library(
      name: "TKCore",
      targets: ["TKCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "7.0.0")),
    .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "11.0.0")),
    .package(url: "https://github.com/aptabase/aptabase-swift.git", .upToNextMajor(from: "0.3.9")),
    .package(path: "../TKUIKit"),
    .package(path: "../core-swift"),
    .package(path: "../Ledger"),
    .package(path: "../TKKeychain")
  ],
  targets: [
    .target(
      name: "TKCore",
      dependencies: [
        .byName(name: "Kingfisher"),
        .product(name: "FirebaseAnalyticsWithoutAdIdSupport", package: "firebase-ios-sdk"),
        .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
        .product(name: "Aptabase", package: "aptabase-swift"),
        .product(name: "TKUIKitDynamic", package: "TKUIKit"),
        .product(name: "WalletCore", package: "core-swift"),
        .product(name: "TonTransport", package: "Ledger"),
        .product(name: "TKKeychain", package: "TKKeychain"),
      ],
      resources: [.process("Resources")]),
    .testTarget(
      name: "TKCoreTests",
      dependencies: ["TKCore"]),
  ]
)
