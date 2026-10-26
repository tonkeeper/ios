// swift-tools-version: 6.2

import Foundation
import PackageDescription

/// `verticalBarEdge` exists only in the iOS 27.1 SDK. App-target build settings do not
/// reach this package, so the check lives here and defines `XCODE_VERSION_AT_LEAST_27_1`.
/// The Xcode is located through the loaded `libPackageDescription`: the Xcode GUI does not
/// pass `DEVELOPER_DIR` to the manifest, and `xcode-select` may point at another Xcode.
private enum XcodeVersion {
    static func atLeast(major: Int, minor: Int) -> Bool {
        guard let version = current() else { return false }
        if version.major != major { return version.major > major }
        return version.minor >= minor
    }

    private static func current() -> (major: Int, minor: Int)? {
        var info = Dl_info()
        let symbol = unsafeBitCast(Package.self as AnyClass, to: UnsafeRawPointer.self)
        guard dladdr(symbol, &info) != 0, let libraryPath = info.dli_fname else { return nil }
        var directory = URL(fileURLWithPath: String(cString: libraryPath)).resolvingSymlinksInPath()
        while directory.lastPathComponent != "Contents" {
            guard directory.pathComponents.count > 1 else { return nil }
            directory.deleteLastPathComponent()
        }
        let versionPlist = directory.appendingPathComponent("version.plist")
        guard let version = NSDictionary(contentsOf: versionPlist)?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        let parts = version.split(separator: ".").compactMap { part -> Int? in
            Int(part.prefix { $0.isNumber })
        }
        guard let major = parts.first else { return nil }
        return (major, parts.count > 1 ? parts[1] : 0)
    }
}

private let tkUIKitSwiftSettings: [SwiftSetting] = {
    var settings: [SwiftSetting] = [
        .treatAllWarnings(as: .error),
    ]
    if XcodeVersion.atLeast(major: 27, minor: 1) {
        settings.append(.define("XCODE_VERSION_AT_LEAST_27_1"))
    }
    return settings
}()

private let platformRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
private let resourcesRoot = FileManager.default.fileExists(atPath: platformRoot.appendingPathComponent("resources/Package.swift").path)
    ? platformRoot.appendingPathComponent("resources")
    : platformRoot.deletingLastPathComponent().appendingPathComponent("shared/resources")

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
        // (like `SnapKit-Dynamic`). That makes the dynamic `KeeperResources` library build as
        // a single shared framework — embedded once and reused by the app + extensions — rather
        // than being statically copied into every consumer. A same-package target dependency
        // can't be built dynamically, so the separate package is required.
        .package(path: resourcesRoot.path),
    ],
    targets: [
        .target(
            name: "TKUIKit",
            dependencies: [
                .product(name: "KeeperResources", package: "resources"),
                .product(name: "SnapKit-Dynamic", package: "SnapKit"),
                .byName(name: "Kingfisher"),
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "TKLogging", package: "TKLogging"),
                .product(name: "TKLocalize", package: "TKLocalize"),
            ],
            path: "TKUIKit/Sources/TKUIKit",

            swiftSettings: tkUIKitSwiftSettings
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
