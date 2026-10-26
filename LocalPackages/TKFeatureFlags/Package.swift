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
        // reads the other. The Firebase-backed `RemoteConfigProvider` lives in `App`.
        .library(
            name: "TKFeatureFlags",
            targets: ["TKFeatureFlags"]
        ),
    ],
    dependencies: [
        .package(path: "../TKAppInfo"),
        .package(path: "../TKLogging"),
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
    ],
    swiftLanguageModes: [.v5]
)
