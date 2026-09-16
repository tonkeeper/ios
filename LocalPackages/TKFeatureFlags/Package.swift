// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKFeatureFlags",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        // Firebase-free on purpose. `KeeperCore` depends on this and is built as a dynamic
        // framework, so anything Firebase reachable from here would be linked a second time
        // into that framework — giving the process two `FIRApp` classes, two registries, and
        // a `FIRAppNotConfigured` crash when `configure()` lands in one and `remoteConfig()`
        // reads the other. Only the app binary may link Firebase.
        .library(
            name: "TKFeatureFlags",
            targets: ["TKFeatureFlags"]
        ),
        // The Firebase-backed `RemoteConfigProvider`. Only the app target may depend on this.
        .library(
            name: "TKFeatureFlagsFirebase",
            targets: ["TKFeatureFlagsFirebase"]
        ),
    ],
    dependencies: [
        .package(path: "../TKAppInfo"),
        .package(path: "../TKLogging"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.8.0")),
    ],
    targets: [
        .target(
            name: "TKFeatureFlags",
            dependencies: [
                "TKAppInfo",
                "TKLogging",
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .target(
            name: "TKFeatureFlagsFirebase",
            dependencies: [
                "TKFeatureFlags",
                "TKLogging",
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
