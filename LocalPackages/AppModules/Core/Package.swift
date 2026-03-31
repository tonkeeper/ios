// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        ),
    ],
    targets: [
        .target(
            name: "Core",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
