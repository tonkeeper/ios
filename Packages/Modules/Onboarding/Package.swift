// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Onboarding",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "Onboarding",
            targets: ["Onboarding"]),
    ],
    dependencies: [
      .package(url: "git@github.com:tonkeeper/tkuikit-ios.git", branch: "main"),
      .package(url: "https://github.com/tonkeeper/core-swift", branch: "release/1.0.0"),
      .package(path: "../TKCoordinator"),
      .package(path: "../Passcode"),
      .package(path: "../TKCore"),
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: [
              .product(name: "TKUIKit", package: "tkuikit-ios"),
              .product(name: "TKScreenKit", package: "tkuikit-ios"),
              .product(name: "TKCoordinator", package: "TKCoordinator"),
              .product(name: "TKCore", package: "TKCore"),
              .product(name: "WalletCore", package: "core-swift"),
              .product(name: "Passcode", package: "Passcode")
            ]
        ),
    ]
)
