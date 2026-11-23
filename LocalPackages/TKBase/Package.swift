// swift-tools-version: 6.2

import PackageDescription

let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

/// One product for the base modules that both `KeeperCore` and `TKUIKit` use, so the app and
/// its extensions load them as a single framework. Each module keeps its own folder under
/// `LocalPackages/<Module>`; `Sources/` and `Tests/` link to them.
///
/// Firebase-free on purpose: anything Firebase reachable from here would be linked a second time,
/// into this framework as well as into the app, giving the process two `FIRApp` classes and a
/// `FIRAppNotConfigured` crash. The Firebase-backed `RemoteConfigProvider` lives in `App`.
let package = Package(
    name: "TKBase",
    defaultLocalization: "EN",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "TKBase",
            targets: [
                "TKLogging",
                "TKLocalize",
                "TKAppInfo",
                "TKFeatureFlags",
                "TKKeychain",
                "PerpsModels",
                "OperationReviewModels",
                "AnyCodable",
            ]
        ),
        .library(name: "TKTestSupport", targets: ["TKTestSupport"]),
    ],
    targets: [
        .target(name: "TKLogging", swiftSettings: strict),
        .target(name: "TKLocalize", resources: [.process("Resources/Locales")], swiftSettings: strict),
        .testTarget(name: "TKLocalizeTests", dependencies: ["TKLocalize"], swiftSettings: strict),
        .target(name: "TKAppInfo", swiftSettings: strict),
        .target(name: "TKFeatureFlags", dependencies: ["TKAppInfo", "TKLogging"], swiftSettings: strict),
        .target(name: "TKKeychain", dependencies: ["TKLogging"], swiftSettings: strict),
        .target(
            name: "PerpsModels",
            dependencies: ["OperationReviewModels"],
            swiftSettings: strict + [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .target(
            name: "OperationReviewModels",
            swiftSettings: strict + [.enableUpcomingFeature("StrictConcurrency")]
        ),
        // Vendored Flight-School/AnyCodable 0.6.7 (MIT, see Sources/AnyCodable/LICENSE): as a package
        // product it would become one more framework, because both `KeeperCore` and `TKServices` use it.
        .target(name: "AnyCodable", exclude: ["LICENSE"]),
        // Test targets only: the app must never link XCTest.
        .target(name: "TKTestSupport", swiftSettings: strict + [.swiftLanguageMode(.v6)]),
    ],
    swiftLanguageModes: [.v5]
)
