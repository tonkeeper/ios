// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SignerLocalize",
    defaultLocalization: "EN",
    products: [
        .library(
            name: "SignerLocalize",
            targets: ["SignerLocalize"]),
    ],
    targets: [
        .target(
            name: "SignerLocalize",
            resources: [.process("Resources/Locales")]
        )
    ]
)
