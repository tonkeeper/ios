import CoreText
@testable import TKUIKit
import UIKit
import XCTest

final class TKTypographyTests: XCTestCase {
    private enum Weight {
        case regular
        case medium
        case bold

        var fontFile: TKUIKitFontFile {
            switch self {
            case .regular:
                return .ttfirsneueNm
            case .medium:
                return .ttfirsneueMd
            case .bold:
                return .ttfirsneueDmbd
            }
        }
    }

    private typealias DesignStyle = (
        name: String,
        style: TKTextStyle,
        features: TKFontFeatures,
        weight: Weight,
        size: CGFloat,
        letterSpacing: CGFloat
    )

    private let designSystem: [DesignStyle] = [
        ("balance", .balance, .display, .medium, 44, 0),
        ("num1", .num1, .display, .medium, 32, 0),
        ("num2", .num2, .display, .medium, 28, 0),
        ("h1", .h1, .display, .bold, 32, 0),
        ("h2", .h2, .display, .bold, 24, 0),
        ("h3", .h3, .display, .bold, 20, 0),
        ("label1", .label1, .text, .medium, 16, 0.08),
        ("label2", .label2, .text, .medium, 14, 0.07),
        ("label3", .label3, .text, .medium, 12, 0.12),
        ("body1", .body1, .text, .regular, 16, 0.08),
        ("body2", .body2, .text, .regular, 14, 0.07),
        ("body3", .body3, .text, .regular, 12, 0.12),
        ("body3Alternate", .body3Alternate, .text, .regular, 13, 0.13),
        ("body4", .body4, .text, .medium, 10, 0.1),
        ("body4Bold", .body4Bold, .text, .bold, 10, 0.1),
        ("body4Caps", .body4Caps, .text, .medium, 10, 0.1),
    ]

    func testDesignSystemStylesCarryFigmaFaceAndSize() {
        for entry in designSystem {
            XCTAssertEqual(
                entry.style.font.fontName,
                entry.weight.fontFile.fontName,
                entry.name
            )
            XCTAssertEqual(entry.style.font.pointSize, entry.size, entry.name)
        }
    }

    func testDesignSystemStylesCarryFigmaStylisticSets() {
        for entry in designSystem {
            XCTAssertEqual(
                Set(openTypeTags(of: entry.style.font)),
                expectedStylisticSets(entry.features),
                entry.name
            )
        }
    }

    func testDesignSystemStylesCarryFigmaLetterSpacing() {
        for entry in designSystem {
            XCTAssertEqual(entry.style.letterSpacing, entry.letterSpacing, entry.name)
        }
    }

    func testLetterSpacingReachesAttributedStringAsKern() {
        for entry in designSystem {
            let attributes = entry.style.getAttributes(color: .white)
            XCTAssertEqual(attributes[.kern] as? CGFloat, entry.letterSpacing, entry.name)

            let tabAttributes = entry.style.getTabStyledAttributes(color: .white)
            XCTAssertEqual(tabAttributes[.kern] as? CGFloat, entry.letterSpacing, entry.name)
        }
    }

    func testMonospacedDigitsKeepsStylisticSetsAndLetterSpacing() {
        let style = TKTextStyle.body2.monospacedDigits()

        XCTAssertEqual(Set(openTypeTags(of: style.font)), expectedStylisticSets(.text))
        XCTAssertEqual(style.font.fontName, TKTextStyle.body2.font.fontName)
        XCTAssertEqual(style.font.pointSize, TKTextStyle.body2.font.pointSize)
        XCTAssertEqual(style.letterSpacing, TKTextStyle.body2.letterSpacing)
        XCTAssertEqual(style.lineHeight, TKTextStyle.body2.lineHeight)
        XCTAssertTrue(hasTabularFigures(style.font))
    }

    func testTextStylisticSetSubstitutesLowercaseGlyphs() throws {
        let base = try bundledFont(.ttfirsneueNm)

        XCTAssertNotEqual(
            glyphs(of: "flight jolly typography", in: base.applying(.text)),
            glyphs(of: "flight jolly typography", in: base.applying(.display))
        )
    }

    func testDisplayStylisticSetsSubstituteCapitalGlyphs() throws {
        let base = try bundledFont(.ttfirsneueMd)

        XCTAssertNotEqual(
            glyphs(of: "GRAM & hello@tonkeeper.com", in: base.applying(.display)),
            glyphs(of: "GRAM & hello@tonkeeper.com", in: base)
        )
    }

    func testStylisticSetsLeaveLineMetricsUntouched() throws {
        let base = try bundledFont(.ttfirsneueNm)

        for features in [TKFontFeatures.display, .text] {
            let applied = base.applying(features)
            XCTAssertEqual(applied.lineHeight, base.lineHeight)
            XCTAssertEqual(applied.ascender, base.ascender)
            XCTAssertEqual(applied.descender, base.descender)
        }
    }

    private func expectedStylisticSets(_ features: TKFontFeatures) -> Set<String> {
        Set(features.stylisticSets.map(\.rawValue))
    }

    private func bundledFont(_ file: TKUIKitFontFile) throws -> UIFont {
        try registerFont(file: file)
        return try XCTUnwrap(UIFont(name: file.fontName, size: 16))
    }

    private func openTypeTags(of font: UIFont) -> [String] {
        let settings = font.fontDescriptor.fontAttributes[.featureSettings] as? [[String: Any]] ?? []
        return settings.compactMap { $0[kCTFontOpenTypeFeatureTag as String] as? String }
    }

    private func hasTabularFigures(_ font: UIFont) -> Bool {
        let settings = font.fontDescriptor.fontAttributes[.featureSettings] as? [[String: Any]] ?? []
        return settings.contains { setting in
            setting[UIFontDescriptor.FeatureKey.type.rawValue] as? Int == kNumberSpacingType
                && setting[UIFontDescriptor.FeatureKey.selector.rawValue] as? Int == kMonospacedNumbersSelector
        }
    }

    private func glyphs(of string: String, in font: UIFont) -> [CGGlyph] {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: string, attributes: [.font: font])
        )
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        return runs.flatMap { run -> [CGGlyph] in
            let count = CTRunGetGlyphCount(run)
            var buffer = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &buffer)
            return buffer
        }
    }
}
