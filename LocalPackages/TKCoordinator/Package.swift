// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKCoordinator",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "TKCoordinator",
            targets: ["TKCoordinator"]
        ),
    ],
    dependencies: [
        .package(path: "../TKBase"),
    ],
    targets: [
        .target(
            name: "TKCoordinator",
            dependencies: [
                .product(name: "TKBase", package: "TKBase"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
