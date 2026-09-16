// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKUIKit",
    platforms: [.iOS(.v15)],
    products: [
        // Statically linked (automatic). Keeping this product non-`.dynamic` is what fixes
        // SwiftUI Previews: importing an explicitly `.dynamic` product force-promotes
        // transitive deps (e.g. Kingfisher) into synthesized `*_PackageProduct.framework`s
        // that XCPreviewAgent can't locate.
        .library(
            name: "TKUIKit",
            targets: ["TKUIKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/SVGKit/SVGKit.git", revision: "9b573a08e7698149de1a0ed576f22f68f5a0e30b"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", exact: "4.6.0"),
        .package(path: "../TKLogging"),
        .package(path: "../TKLocalize"),
        // Resources live in their own package so `TKUIKit` depends on them as a *product*
        // (like `SnapKit-Dynamic`). That makes the dynamic `TKUIKitResources` library build as
        // a single shared framework — embedded once and reused by the app + extensions — rather
        // than being statically copied into every consumer. A same-package target dependency
        // can't be built dynamically, so the separate package is required.
        .package(path: "../TKUIKitResources"),
    ],
    targets: [
        .target(
            name: "TKUIKit",
            dependencies: [
                .product(name: "TKUIKitResources", package: "TKUIKitResources"),
                .product(name: "SnapKit-Dynamic", package: "SnapKit"),
                .byName(name: "Kingfisher"),
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TKLocalize", package: "TKLocalize"),
            ],
            path: "TKUIKit/Sources/TKUIKit",

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
        .testTarget(
            name: "TKUIKitTests",
            dependencies: ["TKUIKit"],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
