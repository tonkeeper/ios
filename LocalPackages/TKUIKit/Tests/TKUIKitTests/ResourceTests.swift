import SwiftUI
@testable import TKUIKit
import TKUIKitResources
import UIKit
import XCTest

@MainActor
final class ResourceTests: XCTestCase {
    func testLottieManifestMatchesModuleBundle() throws {
        let manifestFiles = Set(TKUIKitLottieFile.allCases.map(\.rawValue))
        let resourceFiles = try resourceFileNames(
            in: XCTUnwrap(TKUIKitLottieFile.resourceDirectoryURL),
            matchingExtension: "json"
        )

        XCTAssertEqual(manifestFiles, resourceFiles)
    }

    func testFontManifestMatchesModuleBundle() throws {
        let manifestFiles = Set(TKUIKitFontFile.allCases.map(\.fileName))
        let resourceFiles = try resourceFileNames(
            in: XCTUnwrap(TKUIKitFontFile.resourceDirectoryURL),
            matchingExtension: "ttf"
        )

        XCTAssertEqual(manifestFiles, resourceFiles)
    }

    func testGeneratedFontCasesUseFullFileBasename() {
        XCTAssertEqual(TKUIKitFontFile.ttfirsneueNm.fileName, "TTFirsNeue-Nm.ttf")
        XCTAssertEqual(TKUIKitFontFile.ttfirsneueMd.fileName, "TTFirsNeue-Md.ttf")
        XCTAssertEqual(TKUIKitFontFile.ttfirsneueDmbd.fileName, "TTFirsNeue-DmBd.ttf")
    }

    func testUIFontFacadeResolvesTheThreeTypefaceWeights() {
        XCTAssertEqual(UIFont.tkRegular(size: 12, features: .text).fontName, TKUIKitFontFile.ttfirsneueNm.fontName)
        XCTAssertEqual(UIFont.tkMedium(size: 12, features: .text).fontName, TKUIKitFontFile.ttfirsneueMd.fontName)
        XCTAssertEqual(UIFont.tkBold(size: 12, features: .text).fontName, TKUIKitFontFile.ttfirsneueDmbd.fontName)
    }

    func testFontWeightsResolveToDistinctFiles() throws {
        let files: [TKUIKitFontFile] = [.ttfirsneueNm, .ttfirsneueMd, .ttfirsneueDmbd]

        XCTAssertEqual(Set(files).count, files.count, "the weights reuse the same file")

        for file in files {
            try registerFont(file: file)
            XCTAssertNotNil(
                UIFont(name: file.fontName, size: 12),
                "\(file.fileName) does not resolve by its PostScript name"
            )
        }
    }

    func testAllFontManifestFilesRegister() throws {
        for file in TKUIKitFontFile.allCases {
            XCTAssertNotNil(
                file.url,
                "Missing font file: \(file.fileName)"
            )

            try registerFont(file: file)
            try registerFont(file: file)
            XCTAssertNotNil(
                UIFont(name: file.fontName, size: 12),
                "Failed to load registered font: \(file.fontName)"
            )
        }
    }

    func testColorManifestMatchesAssetCatalog() throws {
        let manifestResources = Set(TKUIKitGeneratedColorAsset.allCases.map(\.rawValue))
        let catalogResources = try colorResourceNames(in: colorsRoot)

        XCTAssertEqual(manifestResources, catalogResources)
        XCTAssertEqual(manifestResources.count, 3 * 55)
    }

    func testColorThemesHaveIdenticalTokenPaths() throws {
        let resourceNames = try colorResourceNames(in: colorsRoot)
        var tokenPathsByTheme = [String: Set<String>]()

        for resourceName in resourceNames {
            let components = resourceName.split(separator: "/").map(String.init)
            guard components.count == 4, components.first == "Colors" else {
                XCTFail("Unexpected color resource path: \(resourceName)")
                continue
            }

            let theme = components[3]
            let tokenPath = "\(components[1])/\(components[2])"
            tokenPathsByTheme[theme, default: []].insert(tokenPath)
        }

        XCTAssertEqual(
            Set(tokenPathsByTheme.keys),
            Set(["Light", "Dark", "DeepBlue"])
        )

        let lightTokenPaths = try XCTUnwrap(tokenPathsByTheme["Light"])
        XCTAssertEqual(lightTokenPaths.count, 55)
        XCTAssertEqual(try XCTUnwrap(tokenPathsByTheme["Dark"]), lightTokenPaths)
        XCTAssertEqual(try XCTUnwrap(tokenPathsByTheme["DeepBlue"]), lightTokenPaths)
    }

    func testColorAssetsUseSingleUniversalSRGBDefinition() throws {
        for colorSetURL in try colorSetURLs(in: colorsRoot) {
            let contents = try JSONDecoder().decode(
                ColorSetContents.self,
                from: Data(contentsOf: colorSetURL.appendingPathComponent("Contents.json"))
            )
            let resourcePath = resourceRelativePath(colorSetURL)

            XCTAssertEqual(contents.colors.count, 1, resourcePath)
            let color = try XCTUnwrap(contents.colors.first)
            XCTAssertEqual(color.idiom, "universal", resourcePath)
            XCTAssertNil(color.appearances, resourcePath)
            XCTAssertEqual(color.color.colorSpace, "srgb", resourcePath)
        }
    }

    func testAllGeneratedColorManifestEntriesLoad() {
        for asset in TKUIKitGeneratedColorAsset.allCases {
            XCTAssertNotNil(
                UIColor(
                    named: asset.rawValue,
                    in: TKUIKitResourcesBundle.bundle,
                    compatibleWith: nil
                ),
                "Missing generated color resource: \(asset.rawValue)"
            )
            _ = asset.uiColor
        }
    }

    func testGeneratedColorSchemesPreserveRepresentativeRGBAValues() {
        let light = LightColorScheme()
        assertColor(light.backgroundContent, hex: 0xFFFFFF)
        assertColor(light.backgroundHighlighted, hex: 0x818C99, alpha: 0.08)
        assertColor(light.buttonPrimaryBackgroundGreenDisabled, hex: 0x2B9962)

        let dark = DarkColorScheme()
        assertColor(dark.backgroundContent, hex: 0x17171A)
        assertColor(dark.fieldErrorBackground, hex: 0xFF4766, alpha: 0.08)

        let deepBlue = DeepBlueColorScheme()
        assertColor(deepBlue.backgroundPage, hex: 0x10161F)
        assertColor(deepBlue.separatorCommon, hex: 0xC2DAFF, alpha: 0.08)
    }

    func testThemeAppearancesUseGeneratedSchemes() {
        let system = SystemThemeAppearance()
        XCTAssertTrue(system.colorScheme(for: .unspecified) is LightColorScheme)
        XCTAssertTrue(system.colorScheme(for: .light) is LightColorScheme)
        XCTAssertTrue(system.colorScheme(for: .dark) is DarkColorScheme)

        let deepBlue = DeepBlueThemeAppearance()
        XCTAssertTrue(deepBlue.colorScheme(for: .light) is DeepBlueColorScheme)
        XCTAssertTrue(deepBlue.colorScheme(for: .dark) is DeepBlueColorScheme)
    }

    func testLegacyUIKitFacadeUsesDynamicThemeColorsAndCompatibilityAliases() {
        let themeManager = TKThemeManager.shared
        let originalTheme = themeManager.theme
        defer {
            themeManager.theme = originalTheme
        }

        themeManager.theme = .system
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        assertColor(
            UIColor.Background.content.resolvedColor(with: lightTraits),
            hex: 0xFFFFFF
        )
        assertColor(
            UIColor.Background.content.resolvedColor(with: darkTraits),
            hex: 0x17171A
        )
        assertColor(
            UIColor.Button.overlayBackground.resolvedColor(with: darkTraits),
            hex: 0xFFFFFF
        )
        assertColor(
            UIColor.Button.overlayBackgroundDisabled.resolvedColor(with: darkTraits),
            hex: 0xFFFFFF
        )
        assertColor(
            UIColor.Button.overlayBackgroundHighlighted.resolvedColor(with: darkTraits),
            hex: 0xFFFFFF
        )
        assertColor(
            UIColor.Button.overlayForeground.resolvedColor(with: darkTraits),
            hex: 0x000000
        )
    }

    /// TKColor statics share implicit-member namespaces with SwiftUI's
    /// ShapeStyle vocabulary in the themed modifier overloads; a token named
    /// like a native style would silently change overload resolution.
    func testColorTokenNamesStayOutOfSwiftUIStyleVocabulary() {
        let denylist: Set<String> = [
            "clear", "primary", "secondary", "tertiary", "quaternary",
            "tint", "foreground", "red", "blue", "green", "orange", "purple",
            "pink", "yellow", "black", "white", "gray", "mint", "teal",
            "cyan", "indigo", "brown", "bar",
        ]

        for token in TKColorToken.allCases {
            let name = String(describing: token)
            XCTAssertFalse(
                denylist.contains(name),
                "Token \(name) collides with SwiftUI style vocabulary"
            )
            XCTAssertFalse(
                name.hasSuffix("Material"),
                "Token \(name) collides with SwiftUI material vocabulary"
            )
        }
    }

    func testSwiftUIColorSchemeMatchesConcreteColorScheme() {
        let colorSchemes: [(TKColorScheme, TKResolvedTheme)] = [
            (LightColorScheme(), .light),
            (DarkColorScheme(), .dark),
            (DeepBlueColorScheme(), .deepBlue),
        ]

        for (colorScheme, resolvedTheme) in colorSchemes {
            let swiftUI = resolvedTheme.palette
            assertColorsEqual(
                colorScheme.backgroundContent,
                UIColor(swiftUI.background.content)
            )
            assertColorsEqual(
                colorScheme.buttonPrimaryBackgroundGreenDisabled,
                UIColor(swiftUI.button.primaryBackgroundGreenDisabled)
            )
            assertColorsEqual(
                colorScheme.constantTonBlue,
                UIColor(swiftUI.constant.tonBlue)
            )
        }
    }

    func testImageManifestMatchesAssetCatalog() throws {
        let manifestResources = Set(TKUIKitGeneratedImageAsset.allCases.map(\.resourceName))
        let catalogResources = try imageRootDirectories.reduce(into: Set<String>()) { result, rootDirectory in
            try result.formUnion(
                imageResourceNames(
                    in: rootDirectory.url,
                    namespace: rootDirectory.namespace
                )
            )
        }

        XCTAssertEqual(manifestResources, catalogResources)
    }

    func testIconsUseFlatSizeFirstHierarchy() throws {
        let catalogResources = try imageResourceNames(
            in: resourcesRoot.appendingPathComponent("Assets.xcassets/Icons"),
            namespace: "Icons"
        )
        let violations = catalogResources.compactMap { resourceName -> String? in
            let components = resourceName.split(separator: "/").map(String.init)
            guard components.count == 3,
                  components.first == "Icons",
                  sizeValue(components[1]) != nil
            else {
                return resourceName
            }

            return nil
        }

        XCTAssertEqual(violations.sorted(), [])
    }

    func testImageAssetNamesDoNotRepeatSizeNamespace() throws {
        let catalogResources = try imageResourceNames(
            in: resourcesRoot.appendingPathComponent("Assets.xcassets/Icons"),
            namespace: "Icons"
        )
        let violations = catalogResources.compactMap { resourceName -> String? in
            let components = resourceName.split(separator: "/").map(String.init)
            guard let assetName = components.last else {
                return nil
            }

            let assetNameComponents = splitNameComponents(assetName)
            for namespace in components.dropLast() {
                guard let size = sizeValue(namespace),
                      assetNameComponents.contains(size)
                else {
                    continue
                }

                return resourceName
            }

            return nil
        }

        XCTAssertEqual(violations.sorted(), [])
    }

    func testIconImagesetsUseNormalizedNames() throws {
        let iconsDirectory = resourcesRoot.appendingPathComponent("Assets.xcassets/Icons")
        let imagesetURLs = try imageSetURLs(in: iconsDirectory)
        var imagesetNameViolations = [String]()
        var filenameViolations = [String]()

        for imagesetURL in imagesetURLs {
            let imagesetName = imagesetURL.deletingPathExtension().lastPathComponent
            if !isKebabCase(imagesetName) {
                imagesetNameViolations.append(resourceRelativePath(imagesetURL))
            }

            guard let size = sizeValue(imagesetURL.deletingLastPathComponent().lastPathComponent) else {
                continue
            }

            let expectedFilenameStem = "\(imagesetName)-\(size)"
            let contentsURL = imagesetURL.appendingPathComponent("Contents.json")
            let contents = try JSONDecoder().decode(
                ImageSetContents.self,
                from: Data(contentsOf: contentsURL)
            )

            for image in contents.images {
                guard let filename = image.filename else {
                    continue
                }

                let stem = URL(fileURLWithPath: filename)
                    .deletingPathExtension()
                    .lastPathComponent
                let normalizedStem = stem.replacingOccurrences(
                    of: #"@[23]x$"#,
                    with: "",
                    options: .regularExpression
                )
                guard normalizedStem != expectedFilenameStem else {
                    continue
                }

                filenameViolations.append("\(resourceRelativePath(imagesetURL)): \(filename)")
            }
        }

        XCTAssertEqual(imagesetNameViolations.sorted(), [])
        XCTAssertEqual(filenameViolations.sorted(), [])
    }

    func testAllGeneratedImageManifestEntriesLoad() throws {
        for asset in TKUIKitGeneratedImageAsset.allCases {
            let image = try XCTUnwrap(
                UIImage(
                    named: asset.resourceName,
                    in: TKUIKitResourcesBundle.bundle,
                    compatibleWith: nil
                ),
                "Missing generated image resource: \(asset.resourceName)"
            )
            XCTAssertNotEqual(
                image.size,
                .zero,
                "Missing generated image resource: \(asset.resourceName)"
            )
        }
    }

    func testImageRuntimeUsesGeneratedAssetResources() throws {
        let imageFiles = [
            sourceRoot.appendingPathComponent("UIKit/Components/Views/TKFancyQRCodeView.swift"),
        ]

        for fileURL in imageFiles {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertFalse(
                contents.contains(".imageWithName("),
                "\(fileURL.lastPathComponent) should use generated asset symbols"
            )
            XCTAssertFalse(
                contents.contains("UIImage(named:"),
                "\(fileURL.lastPathComponent) should use generated asset symbols"
            )
            XCTAssertFalse(
                contents.contains("Image(\""),
                "\(fileURL.lastPathComponent) should use generated asset symbols"
            )
        }
    }

    func testUIKitImageFacadeReturnsImages() {
        let images = [
            UIImage.TKUIKit.Icons.Size16.close,
            UIImage.TKUIKit.Icons.Size20.tonChain,
            UIImage.TKUIKit.Icons.Size24.batteryBody,
            UIImage.TKUIKit.Icons.Size20.cryptoTon,
            UIImage.TKUIKit.Icons.Size44.currencyUsdt,
            UIImage.TKUIKit.Artwork.Stories.gasless,
            UIImage.TKUIKit.Icons.Size72.serviceWallet,
            UIImage.TKUIKit.Icons.Size72.tonkeeperLogo,
            UIImage.TKUIKit.Textures.textSpoiler,
        ]

        for image in images {
            XCTAssertNotEqual(image.size, .zero)
        }

        XCTAssertEqual(UIImage.TKUIKit.Icons.Size16.close.renderingMode, .alwaysTemplate)
        XCTAssertNotEqual(UIImage.TKUIKit.Icons.Size20.tonChain.renderingMode, .alwaysTemplate)
    }

    func testSwiftUIImageFacadeCompilesForRepresentativeAssets() {
        _ = SwiftUI.Image.TKUIKit.Icons.Size16.close
        _ = SwiftUI.Image.TKUIKit.Icons.Size84.camera
        _ = SwiftUI.Image.TKUIKit.Icons.Size20.cryptoUsdt
        _ = SwiftUI.Image.TKUIKit.Icons.Size44.currencyUsdt
        _ = SwiftUI.Image.TKUIKit.Artwork.Stories.gasless
        _ = SwiftUI.Image.TKUIKit.Artwork.Banners.multichain
        _ = SwiftUI.Image.TKUIKit.Icons.Size72.serviceWallet
        _ = SwiftUI.Image.TKUIKit.Icons.Size16.batteryFlash
        _ = SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarWallet
        _ = SwiftUI.Image.TKUIKit.Icons.Size72.tonkeeperLogo
    }

    func testLottieAndFontFacadesDoNotDeclareRawFilenames() throws {
        let lottieResource = sourceRoot.appendingPathComponent("Shared/LottieResource.swift")
        let lottieContents = try String(contentsOf: lottieResource, encoding: .utf8)
        XCTAssertFalse(
            lottieContents.contains("TKUIKitLottieFile."),
            "\(lottieResource.lastPathComponent) should not declare generated Lottie facade entries"
        )
        for file in TKUIKitLottieFile.allCases {
            XCTAssertFalse(
                lottieContents.contains(file.rawValue),
                "\(lottieResource.lastPathComponent) should use generated Lottie cases"
            )
        }

        let fontFacade = sourceRoot.appendingPathComponent("Fonts/UIFont+TKFont.swift")
        let fontContents = try String(contentsOf: fontFacade, encoding: .utf8)
        XCTAssertFalse(
            fontContents.contains("Bundle.module.url(forResource:"),
            "\(fontFacade.lastPathComponent) should use generated font file URLs"
        )
        for file in TKUIKitFontFile.allCases {
            XCTAssertFalse(
                fontContents.contains(file.fileName),
                "\(fontFacade.lastPathComponent) should use generated font cases"
            )
            XCTAssertFalse(
                fontContents.contains(file.fontName),
                "\(fontFacade.lastPathComponent) should use generated font cases"
            )
        }
    }
}

private extension ResourceTests {
    struct ColorSetContents: Decodable {
        let colors: [Color]

        struct Color: Decodable {
            let appearances: [Appearance]?
            let color: Definition
            let idiom: String
        }

        struct Appearance: Decodable {
            let appearance: String
            let value: String
        }

        struct Definition: Decodable {
            let colorSpace: String

            enum CodingKeys: String, CodingKey {
                case colorSpace = "color-space"
            }
        }
    }

    struct ImageRootDirectory {
        let namespace: String
        let url: URL
    }

    struct ImageSetContents: Decodable {
        let images: [ImageSetImage]
    }

    struct ImageSetImage: Decodable {
        let filename: String?
    }

    var sourceRoot: URL {
        packageRoot.appendingPathComponent("TKUIKit/Sources/TKUIKit")
    }

    var resourcesRoot: URL {
        // Resources live in the sibling `TKUIKitResources` package.
        packageRoot
            .deletingLastPathComponent()
            .appendingPathComponent("TKUIKitResources/Sources/TKUIKitResources/Resources")
    }

    var colorsRoot: URL {
        resourcesRoot.appendingPathComponent("Assets.xcassets/Colors")
    }

    var imageRootDirectories: [ImageRootDirectory] {
        [
            ImageRootDirectory(
                namespace: "Icons",
                url: resourcesRoot.appendingPathComponent("Assets.xcassets/Icons")
            ),
            ImageRootDirectory(
                namespace: "Artwork",
                url: resourcesRoot.appendingPathComponent("Assets.xcassets/Artwork")
            ),
            ImageRootDirectory(
                namespace: "Textures",
                url: resourcesRoot.appendingPathComponent("Assets.xcassets/Textures")
            ),
        ]
    }

    var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func resourceFileNames(
        in directory: URL,
        matchingExtension fileExtension: String
    ) throws -> Set<String> {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try Set(fileURLs.compactMap { fileURL in
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true,
                  fileURL.pathExtension == fileExtension
            else {
                return nil
            }
            return fileURL.lastPathComponent
        })
    }

    func imageResourceNames(
        in imageDirectory: URL,
        namespace: String
    ) throws -> Set<String> {
        let imagesetURLs = try imageSetURLs(in: imageDirectory)
        var names = Set<String>()
        for fileURL in imagesetURLs {
            var relativePath = fileURL.path
            let prefix = imageDirectory.path + "/"
            if relativePath.hasPrefix(prefix) {
                relativePath.removeFirst(prefix.count)
            }
            if relativePath.hasSuffix(".imageset") {
                relativePath.removeLast(".imageset".count)
            }

            names.insert(namespace + "/" + relativePath)
        }

        return names
    }

    func colorResourceNames(in colorDirectory: URL) throws -> Set<String> {
        let colorSetURLs = try colorSetURLs(in: colorDirectory)
        var names = Set<String>()

        for fileURL in colorSetURLs {
            var relativePath = fileURL.path
            let prefix = colorDirectory.path + "/"
            if relativePath.hasPrefix(prefix) {
                relativePath.removeFirst(prefix.count)
            }
            if relativePath.hasSuffix(".colorset") {
                relativePath.removeLast(".colorset".count)
            }

            names.insert("Colors/" + relativePath)
        }

        return names
    }

    func colorSetURLs(in colorDirectory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: colorDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var colorSetURLs = [URL]()
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "colorset" else {
                continue
            }

            colorSetURLs.append(fileURL)
            enumerator.skipDescendants()
        }

        return colorSetURLs
    }

    func imageSetURLs(in imageDirectory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: imageDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var imageSetURLs = [URL]()
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "imageset" else {
                continue
            }

            imageSetURLs.append(fileURL)
            enumerator.skipDescendants()
        }

        return imageSetURLs
    }

    func resourceRelativePath(_ fileURL: URL) -> String {
        var relativePath = fileURL.path
        let prefix = resourcesRoot.path + "/"
        if relativePath.hasPrefix(prefix) {
            relativePath.removeFirst(prefix.count)
        }
        return relativePath
    }

    func isKebabCase(_ value: String) -> Bool {
        value.range(
            of: #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#,
            options: .regularExpression
        ) != nil
    }

    func sizeValue(_ value: String) -> String? {
        if value.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil {
            return value
        }

        if value.hasPrefix("Size") {
            let suffix = String(value.dropFirst("Size".count))
            if suffix.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil {
                return suffix
            }
        }

        return nil
    }

    func splitNameComponents(_ value: String) -> [String] {
        value.replacingOccurrences(
            of: "[^A-Za-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        .split(separator: " ")
        .map(String.init)
    }

    func assertColor(
        _ color: UIColor,
        hex: UInt32,
        alpha expectedAlpha: CGFloat = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            XCTFail("Unable to read color components", file: file, line: line)
            return
        }

        XCTAssertEqual(
            red,
            CGFloat((hex >> 16) & 0xFF) / 255,
            accuracy: 0.002,
            file: file,
            line: line
        )
        XCTAssertEqual(
            green,
            CGFloat((hex >> 8) & 0xFF) / 255,
            accuracy: 0.002,
            file: file,
            line: line
        )
        XCTAssertEqual(
            blue,
            CGFloat(hex & 0xFF) / 255,
            accuracy: 0.002,
            file: file,
            line: line
        )
        XCTAssertEqual(
            alpha,
            expectedAlpha,
            accuracy: 0.002,
            file: file,
            line: line
        )
    }

    func assertColorsEqual(
        _ lhs: UIColor,
        _ rhs: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        guard lhs.getRed(
            &lhsRed,
            green: &lhsGreen,
            blue: &lhsBlue,
            alpha: &lhsAlpha
        ) else {
            XCTFail("Unable to read source color components", file: file, line: line)
            return
        }

        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0
        guard rhs.getRed(
            &rhsRed,
            green: &rhsGreen,
            blue: &rhsBlue,
            alpha: &rhsAlpha
        ) else {
            XCTFail("Unable to read SwiftUI color components", file: file, line: line)
            return
        }

        XCTAssertEqual(lhsRed, rhsRed, accuracy: 0.002, file: file, line: line)
        XCTAssertEqual(lhsGreen, rhsGreen, accuracy: 0.002, file: file, line: line)
        XCTAssertEqual(lhsBlue, rhsBlue, accuracy: 0.002, file: file, line: line)
        XCTAssertEqual(lhsAlpha, rhsAlpha, accuracy: 0.002, file: file, line: line)
    }
}
