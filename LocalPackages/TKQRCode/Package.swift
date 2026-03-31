// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKQRCode",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "TKQRCode",
            type: .dynamic,
            targets: ["TKQRCode"]
        ),
    ],
    targets: [
        .target(
            name: "TKQRCode",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
