// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Resources",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Resources",
            targets: ["Resources"]
        ),
    ],
    targets: [
        .target(
            name: "Resources",
            resources: [.process("Assets")],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
