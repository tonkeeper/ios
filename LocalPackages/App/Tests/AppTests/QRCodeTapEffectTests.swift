import Foundation
@testable import TKUIKit
import XCTest

final class QRCodeTapEffectTests: XCTestCase {
    func testActiveTapInfluenceIsMaximumAtTapOrigin() {
        let influence = QrCodeTapEffect.influence(
            at: QRCodeViewTestConstants.activeTapOrigin,
            activeTapOrigin: QRCodeViewTestConstants.activeTapOrigin,
            moduleSide: QRCodeViewTestConstants.tapModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.tapRippleConfiguration
        )

        XCTAssertEqual(
            influence,
            QrCodeTapEffect.maximumInfluence,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }

    func testActiveTapInfluenceFallsToZeroOutsideLocalRadius() {
        let point = CGPoint(
            x: QRCodeViewTestConstants.activeTapOrigin.x
                + QRCodeViewTestConstants.tapRadius
                + 0.01,
            y: QRCodeViewTestConstants.activeTapOrigin.y
        )
        let influence = QrCodeTapEffect.influence(
            at: point,
            activeTapOrigin: QRCodeViewTestConstants.activeTapOrigin,
            moduleSide: QRCodeViewTestConstants.tapModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.tapRippleConfiguration
        )

        XCTAssertEqual(
            influence,
            0,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }

    func testActiveTapInfluenceUsesConfiguredRadiusIndependentFromRippleRingWidth() {
        let point = CGPoint(
            x: QRCodeViewTestConstants.activeTapOrigin.x
                + QRCodeViewTestConstants.expandedTapRadius * 0.75,
            y: QRCodeViewTestConstants.activeTapOrigin.y
        )
        let influence = QrCodeTapEffect.influence(
            at: point,
            activeTapOrigin: QRCodeViewTestConstants.activeTapOrigin,
            moduleSide: QRCodeViewTestConstants.tapModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.expandedTapRippleConfiguration
        )

        XCTAssertEqual(
            influence,
            0.25,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }

    func testActiveTapInfluenceIsStrongerCloserToTapOrigin() {
        let nearPoint = CGPoint(
            x: QRCodeViewTestConstants.activeTapOrigin.x
                + QRCodeViewTestConstants.tapRadius * 0.25,
            y: QRCodeViewTestConstants.activeTapOrigin.y
        )
        let farPoint = CGPoint(
            x: QRCodeViewTestConstants.activeTapOrigin.x
                + QRCodeViewTestConstants.tapRadius * 0.75,
            y: QRCodeViewTestConstants.activeTapOrigin.y
        )

        let nearInfluence = QrCodeTapEffect.influence(
            at: nearPoint,
            activeTapOrigin: QRCodeViewTestConstants.activeTapOrigin,
            moduleSide: QRCodeViewTestConstants.tapModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.tapRippleConfiguration
        )
        let farInfluence = QrCodeTapEffect.influence(
            at: farPoint,
            activeTapOrigin: QRCodeViewTestConstants.activeTapOrigin,
            moduleSide: QRCodeViewTestConstants.tapModuleSide,
            rippleConfiguration: QRCodeViewTestConstants.tapRippleConfiguration
        )

        XCTAssertGreaterThan(nearInfluence, farInfluence)
    }

    func testActiveTapAndRippleInfluenceClampToMaximum() {
        let startDate = Date(timeIntervalSinceReferenceDate: 1000)
        let ripple = QrCodeRipple(
            origin: QRCodeViewTestConstants.rippleOrigin,
            startDate: startDate
        )
        let influence = QrCodeTapEffect.combinedInfluence(
            at: QRCodeViewTestConstants.rippleRingMidpoint,
            activeTapOrigin: QRCodeViewTestConstants.rippleRingMidpoint,
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
            QrCodeTapEffect.maximumInfluence,
            accuracy: QRCodeViewTestConstants.influenceAccuracy
        )
    }
}
