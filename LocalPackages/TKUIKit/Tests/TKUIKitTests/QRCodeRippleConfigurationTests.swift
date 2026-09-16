import CoreGraphics
@testable import TKUIKit
import XCTest

final class QRCodeRippleConfigurationTests: XCTestCase {
    func testDefaultFinderPatternOpacityReductionIsHalf() {
        XCTAssertEqual(
            QrCodeRippleConfiguration.default.maxFinderPatternOpacityReduction,
            0.5,
            accuracy: 0.0001
        )
    }

    func testFinderPatternOpacityReductionUsesMinimumValue() {
        XCTAssertEqual(
            QrCodeRippleConfiguration(maxFinderPatternOpacityReduction: -1).maxFinderPatternOpacityReduction,
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            QrCodeRippleConfiguration(maxFinderPatternOpacityReduction: 1).maxFinderPatternOpacityReduction,
            1,
            accuracy: 0.0001
        )
    }

    func testNilInitializerOverridesUseDefaults() {
        let configuration = QrCodeRippleConfiguration(
            animationDuration: nil,
            ringWidthInModules: nil,
            activeTapRadiusInModules: nil,
            maxDotDiameterReduction: nil,
            maxFinderPatternOpacityReduction: nil,
            maxSimultaniousRipplesCount: nil
        )

        XCTAssertEqual(
            configuration.maxFinderPatternOpacityReduction,
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(configuration.animationDuration, QrCodeRippleConfiguration.default.animationDuration)
        XCTAssertEqual(configuration.ringWidthInModules, QrCodeRippleConfiguration.default.ringWidthInModules)
        XCTAssertEqual(configuration.activeTapRadiusInModules, QrCodeRippleConfiguration.default.activeTapRadiusInModules)
        XCTAssertEqual(configuration.maxDotDiameterReduction, QrCodeRippleConfiguration.default.maxDotDiameterReduction)
        XCTAssertEqual(configuration.maxSimultaniousRipplesCount, QrCodeRippleConfiguration.default.maxSimultaniousRipplesCount)
    }
}
