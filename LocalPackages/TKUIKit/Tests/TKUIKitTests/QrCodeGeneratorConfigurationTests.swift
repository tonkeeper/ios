@testable import TKUIKit
import UIKit
import XCTest

final class QrCodeGeneratorConfigurationTests: XCTestCase {
    func testDefaultConfigurationUsesConstants() {
        let configuration = QrCodeGeneratorConfiguration.default

        XCTAssertNil(configuration.centerCutoutSize)
        XCTAssertEqual(configuration.errorCorrectionLevel, .automatic)
        XCTAssertEqual(configuration.quietZoneInModules, 3)
        XCTAssertEqual(configuration.dotDiameterRatio, 0.8, accuracy: 0.0001)
        XCTAssertEqual(configuration.backgroundColor, .white)
    }

    func testNilInitializerOverridesUseDefaults() {
        let configuration = QrCodeGeneratorConfiguration(
            centerCutoutSize: nil,
            errorCorrectionLevel: nil,
            quietZoneInModules: nil,
            dotDiameterRatio: nil
        )

        XCTAssertNil(configuration.centerCutoutSize)
        XCTAssertEqual(configuration.errorCorrectionLevel, .automatic)
        XCTAssertEqual(configuration.quietZoneInModules, 3)
        XCTAssertEqual(configuration.dotDiameterRatio, 0.8, accuracy: 0.0001)
        XCTAssertEqual(configuration.backgroundColor, .white)
    }

    func testInitializerAppliesProvidedValues() {
        let centerCutoutSize = CGSize(width: 44, height: 52)
        let configuration = QrCodeGeneratorConfiguration(
            centerCutoutSize: centerCutoutSize,
            errorCorrectionLevel: .quartile,
            quietZoneInModules: 5,
            dotDiameterRatio: 0.6,
            backgroundColor: .clear
        )

        XCTAssertEqual(configuration.centerCutoutSize, centerCutoutSize)
        XCTAssertEqual(configuration.errorCorrectionLevel, .quartile)
        XCTAssertEqual(configuration.quietZoneInModules, 5)
        XCTAssertEqual(configuration.dotDiameterRatio, 0.6, accuracy: 0.0001)
        XCTAssertEqual(configuration.backgroundColor, .clear)
    }

    func testInitializerUsesDefaultForExplicitNilBackgroundColor() {
        let configuration = QrCodeGeneratorConfiguration(backgroundColor: nil)

        XCTAssertEqual(configuration.backgroundColor, .white)
    }

    func testMinimumValuesAreApplied() {
        let configuration = QrCodeGeneratorConfiguration(
            quietZoneInModules: -1,
            dotDiameterRatio: -1
        )

        XCTAssertEqual(configuration.quietZoneInModules, 0)
        XCTAssertEqual(configuration.dotDiameterRatio, 0, accuracy: 0.0001)
    }

    func testAutomaticErrorCorrectionLevelResolvesFromCenterCutout() {
        XCTAssertEqual(
            QrCodeGeneratorConfiguration().resolvedErrorCorrectionLevel,
            .medium
        )
        XCTAssertEqual(
            QrCodeGeneratorConfiguration(centerCutoutSize: CGSize(width: 44, height: 44))
                .resolvedErrorCorrectionLevel,
            .high
        )
    }

    func testExplicitErrorCorrectionLevelDoesNotResolveAutomatically() {
        let configuration = QrCodeGeneratorConfiguration(
            centerCutoutSize: CGSize(width: 44, height: 44),
            errorCorrectionLevel: .low
        )

        XCTAssertEqual(configuration.resolvedErrorCorrectionLevel, .low)
    }
}
