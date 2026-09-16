import Foundation
@testable import TKUIKit
import XCTest

final class QrCodeRippleEffectTests: XCTestCase {
    func testRippleInfluenceIsZeroBeforeStartAndAfterDuration() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1000)
        let ripple = QrCodeRipple(
            origin: QRCodeViewTestConstants.rippleOrigin,
            startDate: startDate
        )

        XCTAssertEqual(
            QrCodeRippleEffect.combinedInfluence(
                at: QRCodeViewTestConstants.rippleRingMidpoint,
                ripples: [ripple],
                date: startDate.addingTimeInterval(-0.01),
                bounds: QRCodeViewTestConstants.rippleBounds,
                moduleSide: QRCodeViewTestConstants.rippleModuleSide,
                rippleConfiguration: QRCodeViewTestConstants.rippleConfiguration
            ),
            0,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
        XCTAssertEqual(
            QrCodeRippleEffect.combinedInfluence(
                at: QRCodeViewTestConstants.rippleRingMidpoint,
                ripples: [ripple],
                date: startDate.addingTimeInterval(
                    QRCodeViewTestConstants.rippleConfiguration.animationDuration + 0.01
                ),
                bounds: QRCodeViewTestConstants.rippleBounds,
                moduleSide: QRCodeViewTestConstants.rippleModuleSide,
                rippleConfiguration: QRCodeViewTestConstants.rippleConfiguration
            ),
            0,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }

    func testRippleInfluencePeaksNearExpandingRing() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1000)
        let ripple = QrCodeRipple(
            origin: QRCodeViewTestConstants.rippleOrigin,
            startDate: startDate
        )
        let influence = QrCodeRippleEffect.combinedInfluence(
            at: QRCodeViewTestConstants.rippleRingMidpoint,
            ripples: [ripple],
            date: startDate.addingTimeInterval(
                QRCodeViewTestConstants.rippleConfiguration.animationDuration / 2
            ),
            bounds: QRCodeViewTestConstants.rippleBounds,
            moduleSide: QRCodeViewTestConstants.rippleModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.rippleConfiguration
        )

        XCTAssertGreaterThan(influence, 0.95)
    }

    func testRippleInfluenceUsesConfiguredAnimationDuration() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1000)
        let ripple = QrCodeRipple(
            origin: QRCodeViewTestConstants.rippleOrigin,
            startDate: startDate
        )
        let influence = QrCodeRippleEffect.combinedInfluence(
            at: QRCodeViewTestConstants.rippleRingMidpoint,
            ripples: [ripple],
            date: startDate.addingTimeInterval(
                QRCodeViewTestConstants.slowRippleConfiguration.animationDuration / 2
            ),
            bounds: QRCodeViewTestConstants.rippleBounds,
            moduleSide: QRCodeViewTestConstants.rippleModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.slowRippleConfiguration
        )

        XCTAssertGreaterThan(influence, 0.95)
    }

    func testOverlappingRippleInfluenceClampsToMaximum() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1000)
        let ripples = [
            QrCodeRipple(
                origin: QRCodeViewTestConstants.rippleOrigin,
                startDate: startDate
            ),
            QrCodeRipple(
                origin: QRCodeViewTestConstants.rippleOrigin,
                startDate: startDate
            ),
        ]
        let influence = QrCodeRippleEffect.combinedInfluence(
            at: QRCodeViewTestConstants.rippleRingMidpoint,
            ripples: ripples,
            date: startDate.addingTimeInterval(
                QRCodeViewTestConstants.rippleConfiguration.animationDuration / 2
            ),
            bounds: QRCodeViewTestConstants.rippleBounds,
            moduleSide: QRCodeViewTestConstants.rippleModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.rippleConfiguration
        )

        XCTAssertEqual(
            influence,
            QrCodeRippleEffect.maximumInfluence,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }

    func testModulesOutsideRippleRingRemainBaseline() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1000)
        let ripple = QrCodeRipple(
            origin: QRCodeViewTestConstants.rippleOrigin,
            startDate: startDate
        )
        let influence = QrCodeRippleEffect.combinedInfluence(
            at: QRCodeViewTestConstants.rippleOrigin,
            ripples: [ripple],
            date: startDate.addingTimeInterval(
                QRCodeViewTestConstants.rippleConfiguration.animationDuration / 2
            ),
            bounds: QRCodeViewTestConstants.rippleBounds,
            moduleSide: QRCodeViewTestConstants.rippleModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.rippleConfiguration
        )

        XCTAssertEqual(
            influence,
            0,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }
}
