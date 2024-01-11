// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "Modules",
  platforms: [.iOS(.v14)],
  products: [
    .library(
      name: "AppModule",
      targets: ["AppModule"]),
    .library(
      name: "OnboardingModule",
      targets: ["OnboardingModule"]),
    .library(
      name: "PasscodeModule",
      targets: ["PasscodeModule"]),
    .library(
      name: "MainModule",
      targets: ["MainModule"]),
    .library(
      name: "WalletModule",
      targets: ["WalletModule"]),
    .library(
      name: "HistoryModule",
      targets: ["HistoryModule"]),
    .library(
      name: "CollectiblesModule",
      targets: ["CollectiblesModule"]),
    .library(
      name: "SettingsModule",
      targets: ["SettingsModule"])
  ],
  dependencies: [
    .package(url: "https://github.com/tonkeeper/tkuikit-ios.git", branch: "main"),
    .package(url: "https://github.com/tonkeeper/core-swift", branch: "release/1.0.0"),
    .package(path: "../LocalPackages/TKCore"),
    .package(path: "../LocalPackages/TKCoordinator")
  ],
  targets: [
    .target(
      name: "AppModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator"),
        .target(name: "OnboardingModule"),
      ],
      path: "AppModule",
      sources: ["Sources"]
    ),
    .target(
      name: "OnboardingModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKScreenKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator"),
        .product(name: "TKCore", package: "TKCore"),
        .product(name: "WalletCore", package: "core-swift"),
        .target(name: "PasscodeModule"),
      ],
      path: "OnboardingModule",
      sources: ["Sources"],
      resources: [.process("Resources")]
    ),
    .target(
      name: "PasscodeModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCore", package: "TKCore"),
        .product(name: "TKCoordinator", package: "TKCoordinator")
      ],
      path: "PasscodeModule",
      sources: ["Sources"]
    ),
    .target(
      name: "MainModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator")
      ],
      path: "MainModule",
      sources: ["Sources"]
    ),
    .target(
      name: "WalletModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator")
      ],
      path: "WalletModule",
      sources: ["Sources"]
    ),
    .target(
      name: "HistoryModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator")
      ],
      path: "HistoryModule",
      sources: ["Sources"]
    ),
    .target(
      name: "CollectiblesModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator")
      ],
      path: "CollectiblesModule",
      sources: ["Sources"]
    ),
    .target(
      name: "SettingsModule",
      dependencies: [
        .product(name: "TKUIKit", package: "tkuikit-ios"),
        .product(name: "TKCoordinator", package: "TKCoordinator")
      ],
      path: "SettingsModule",
      sources: ["Sources"]
    ),
  ]
)
