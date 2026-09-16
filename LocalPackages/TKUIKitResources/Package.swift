// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TKUIKitResources",
    platforms: [.iOS(.v15)],
    products: [
        // Dependency-free, dynamically linked so the asset catalog / fonts / Lottie are
        // embedded once in the app and shared with the extensions, instead of being copied
        // into every product that statically links `TKUIKit`. It lives in its own package so
        // consumers depend on it as a *product* (like `SnapKit-Dynamic`) — that's what lets it
        // build as a single shared framework. Having no code dependencies, being `.dynamic`
        // does not break SwiftUI Previews.
        .library(
            name: "TKUIKitResources",
            type: .dynamic,
            targets: ["TKUIKitResources"]
        ),
    ],
    targets: [
        .target(
            name: "TKUIKitResources",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/Fonts"),
                .copy("Resources/Lottie"),
            ],

            swiftSettings: [
                .treatAllWarnings(as: .error),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
