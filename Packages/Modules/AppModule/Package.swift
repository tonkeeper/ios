// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppModule",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "AppModule",
            targets: ["AppModule"]),
    ],
    dependencies: [
      .package(path: "../TKCoordinator"),
      .package(path: "Onboarding")
    ],
    targets: [
        .target(
            name: "AppModule",
            dependencies: [
              .product(name: "TKCoordinator", package: "TKCoordinator"),
              .product(name: "Onboarding", package: "Onboarding")
            ])
    ]
)
