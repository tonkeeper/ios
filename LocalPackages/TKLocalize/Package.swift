// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKLocalize",
    defaultLocalization: "EN",
    products: [
        .library(
            name: "TKLocalize",
            targets: ["TKLocalize"]
        ),
    ],
    targets: [
        .target(
            name: "TKLocalize",
            resources: [.process("Resources/Locales")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TKLocalizeTests",
            dependencies: [
                "TKLocalize",
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
