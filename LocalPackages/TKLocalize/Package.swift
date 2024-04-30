// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TKLocalize",
    defaultLocalization: "EN",
    products: [
        .library(
            name: "TKLocalize",
            targets: ["TKLocalize"]),
    ],
    targets: [
        .target(
            name: "TKLocalize")
    ]
)
