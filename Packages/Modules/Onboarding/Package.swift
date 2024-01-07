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
      .package(path: "../TKCoordinator"),
      .package(path: "../TKCore")
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: [
              .product(name: "TKUIKit", package: "tkuikit-ios"),
              .product(name: "TKScreenKit", package: "tkuikit-ios"),
              .product(name: "TKCoordinator", package: "TKCoordinator"),
              .product(name: "TKCore", package: "TKCore")
            ]),
    ]
)
