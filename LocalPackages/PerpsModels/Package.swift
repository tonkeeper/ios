// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PerpsModels",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "PerpsModels",
            targets: ["PerpsModels"]
        ),
    ],
    targets: [
        .target(
            name: "PerpsModels",
            swiftSettings: [
                .treatAllWarnings(as: .error),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
