// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppUI",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "AppUI",
            targets: ["AppUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKUIKit"),
        .package(path: "../../TKLocalize"),
        .package(path: "../../TKAppInfo"),
        .package(path: "../../TKLogging"),
    ],
    targets: [
        .target(
            name: "AppUI",
            dependencies: [
                .product(name: "TKUIKit", package: "TKUIKit"),
                .product(name: "TKLocalize", package: "TKLocalize"),
                .product(name: "TKAppInfo", package: "TKAppInfo"),
                .product(name: "TKLogging", package: "TKLogging"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warnings-as-errors"]),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
