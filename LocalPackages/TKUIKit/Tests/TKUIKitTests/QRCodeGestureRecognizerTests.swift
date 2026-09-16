import SwiftUI
@testable import TKUIKit
import UIKit
import XCTest

final class QRCodeGestureMovementTests: XCTestCase {
    func testMovementWithinThresholdStaysTapAndDoesNotStartTracking() {
        let initialLocation = CGPoint(x: 12, y: 20)
        let currentLocation = CGPoint(
            x: initialLocation.x + QrCodeGestureMovement.movementThreshold,
            y: initialLocation.y
        )

        XCTAssertTrue(
            QrCodeGestureMovement.isTapMovement(
                from: initialLocation,
                to: currentLocation
            )
        )
        XCTAssertFalse(
            QrCodeGestureMovement.shouldBeginTracking(
                from: initialLocation,
                to: currentLocation
            )
        )
    }

    func testMovementBeyondThresholdStartsTrackingAndIsNotTap() {
        let initialLocation = CGPoint(x: 12, y: 20)
        let currentLocation = CGPoint(
            x: initialLocation.x + QrCodeGestureMovement.movementThreshold + 0.01,
            y: initialLocation.y
        )

        XCTAssertFalse(
            QrCodeGestureMovement.isTapMovement(
                from: initialLocation,
                to: currentLocation
            )
        )
        XCTAssertTrue(
            QrCodeGestureMovement.shouldBeginTracking(
                from: initialLocation,
                to: currentLocation
            )
        )
    }
}

final class QRCodeGesturePriorityPolicyTests: XCTestCase {
    func testTrackingDefersToAncestorPanGesture() {
        let rootView = UIView()
        let qrView = UIView()
        rootView.addSubview(qrView)

        let trackingGesture = TouchLocationGestureRecognizer()
        let ancestorPanGesture = UIPanGestureRecognizer()
        qrView.addGestureRecognizer(trackingGesture)
        rootView.addGestureRecognizer(ancestorPanGesture)

        XCTAssertTrue(
            QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                ancestorPanGesture,
                for: trackingGesture
            )
        )
    }

    func testTrackingDefersToAncestorSwipeGesture() {
        let rootView = UIView()
        let qrView = UIView()
        rootView.addSubview(qrView)

        let trackingGesture = TouchLocationGestureRecognizer()
        let ancestorSwipeGesture = UISwipeGestureRecognizer()
        qrView.addGestureRecognizer(trackingGesture)
        rootView.addGestureRecognizer(ancestorSwipeGesture)

        XCTAssertTrue(
            QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                ancestorSwipeGesture,
                for: trackingGesture
            )
        )
    }

    func testTrackingDoesNotDeferToSiblingPanGesture() {
        let rootView = UIView()
        let qrView = UIView()
        let siblingView = UIView()
        rootView.addSubview(qrView)
        rootView.addSubview(siblingView)

        let trackingGesture = TouchLocationGestureRecognizer()
        let siblingPanGesture = UIPanGestureRecognizer()
        qrView.addGestureRecognizer(trackingGesture)
        siblingView.addGestureRecognizer(siblingPanGesture)

        XCTAssertFalse(
            QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                siblingPanGesture,
                for: trackingGesture
            )
        )
    }

    func testTapGestureDoesNotDeferToAncestorPanGesture() {
        let rootView = UIView()
        let qrView = UIView()
        rootView.addSubview(qrView)

        let tapGesture = TapLocationGestureRecognizer()
        let ancestorPanGesture = UIPanGestureRecognizer()
        qrView.addGestureRecognizer(tapGesture)
        rootView.addGestureRecognizer(ancestorPanGesture)

        XCTAssertFalse(
            QrCodeGesturePriorityPolicy.shouldDeferToAncestorSwipeGesture(
                ancestorPanGesture,
                for: tapGesture
            )
        )
    }
}

@MainActor
final class QRCodeInteractionModeTests: XCTestCase {
    func testDefaultQRCodeViewInstallsTapGestureOnly() {
        let recognizers = qrGestureRecognizers(
            for: QrCodeView(matrix: matrix)
        )

        XCTAssertEqual(tapRecognizerCount(in: recognizers), 1)
        XCTAssertEqual(trackingRecognizerCount(in: recognizers), 0)
    }

    func testTapAndDragQRCodeViewInstallsTrackingGesture() {
        let recognizers = qrGestureRecognizers(
            for: QrCodeView(
                matrix: matrix,
                interactionMode: .tapAndDrag
            )
        )

        XCTAssertEqual(tapRecognizerCount(in: recognizers), 1)
        XCTAssertEqual(trackingRecognizerCount(in: recognizers), 1)
    }

    func testDisabledTapReaderInstallsNoQRTouchRecognizers() {
        let recognizers = qrGestureRecognizers(
            for: QrCodeView(matrix: matrix)
                .environment(\.qrCodeTapReaderEnabled, false)
        )

        XCTAssertEqual(tapRecognizerCount(in: recognizers), 0)
        XCTAssertEqual(trackingRecognizerCount(in: recognizers), 0)
    }

    private var matrix: QrCodeMatrix {
        guard let matrix = QrCodeMatrix(
            width: 1,
            height: 1,
            modules: [true]
        ) else {
            preconditionFailure("Invalid QR code matrix")
        }
        return matrix
    }

    private func qrGestureRecognizers<Content: View>(
        for content: Content
    ) -> [UIGestureRecognizer] {
        let window = UIWindow(
            frame: CGRect(
                origin: .zero,
                size: CGSize(width: 120, height: 120)
            )
        )
        let hostingController = TKHostingController(
            content: content.frame(width: 120, height: 120)
        )
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

        let recognizers = qrGestureRecognizers(in: hostingController.view)
        window.isHidden = true
        window.rootViewController = nil
        return recognizers
    }

    private func qrGestureRecognizers(in view: UIView) -> [UIGestureRecognizer] {
        let viewRecognizers = view.gestureRecognizers ?? []
        return viewRecognizers.filter(isQRCodeTouchRecognizer)
            + view.subviews.flatMap(qrGestureRecognizers)
    }

    private func isQRCodeTouchRecognizer(_ recognizer: UIGestureRecognizer) -> Bool {
        recognizer is TouchLocationGestureRecognizer
            || recognizer is TapLocationGestureRecognizer
    }

    private func tapRecognizerCount(in recognizers: [UIGestureRecognizer]) -> Int {
        recognizers.filter { $0 is TapLocationGestureRecognizer }.count
    }

    private func trackingRecognizerCount(in recognizers: [UIGestureRecognizer]) -> Int {
        recognizers.filter { $0 is TouchLocationGestureRecognizer }.count
    }
}
