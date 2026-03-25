// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "UIComponents",
            targets: ["UIComponents"]
        ),
    ],
    dependencies: [
        .package(path: "../../TKUIKit"),
    ],
    targets: [
        .target(
            name: "UIComponents",
            dependencies: [
                .product(name: "TKUIKitDynamic", package: "TKUIKit"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
