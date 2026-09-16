import CoreGraphics
@testable import TKUIKit
import XCTest

final class QRCodeFinderPatternOpacityEffectTests: XCTestCase {
    func testZeroInfluenceKeepsOpacityUnchanged() {
        XCTAssertEqual(
            QrCodeFinderPatternOpacityEffect.opacity(
                influence: 0,
                rippleConfiguration: .default
            ),
            1,
            accuracy: 0.0001
        )
    }

    func testFullInfluenceWithDefaultReductionReducesOpacityByDefaultReduction() {
        XCTAssertEqual(
            QrCodeFinderPatternOpacityEffect.opacity(
                influence: 1,
                rippleConfiguration: .default
            ),
            0.5,
            accuracy: 0.0001
        )
    }

    func testInfluenceClampsIntoSupportedRange() {
        XCTAssertEqual(
            QrCodeFinderPatternOpacityEffect.opacity(
                influence: -1,
                rippleConfiguration: .default
            ),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            QrCodeFinderPatternOpacityEffect.opacity(
                influence: 2,
                rippleConfiguration: .default
            ),
            0.5,
            accuracy: 0.0001
        )
    }
}
