import CoreGraphics
@testable import TKUIKit
import XCTest

final class QRCodeTapHighlightTests: XCTestCase {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1000)
    private let origin = CGPoint(x: 24, y: 32)

    func testPressProgressStartsAtZeroAndReachesOneAfterDuration() {
        let highlight = QrCodeTapHighlight(origin: origin, date: startDate)

        XCTAssertEqual(
            highlight.progress(at: startDate),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            highlight.progress(at: startDate.addingTimeInterval(QrCodeViewLayout.tapHighlightAnimationDuration)),
            1,
            accuracy: 0.0001
        )
    }

    func testReleaseTransitionsFromCurrentProgressToZero() {
        let highlight = QrCodeTapHighlight(origin: origin, date: startDate)
        let releaseDate = startDate.addingTimeInterval(QrCodeViewLayout.tapHighlightAnimationDuration / 2)
        let releaseHighlight = highlight.releasing(at: releaseDate)

        XCTAssertEqual(
            releaseHighlight.progress(at: releaseDate),
            highlight.progress(at: releaseDate),
            accuracy: 0.0001
        )
        XCTAssertEqual(
            releaseHighlight.progress(at: releaseDate.addingTimeInterval(QrCodeViewLayout.tapHighlightAnimationDuration)),
            0,
            accuracy: 0.0001
        )
    }

    func testProgressClampsIntoZeroOneRange() {
        let highlight = QrCodeTapHighlight(origin: origin, date: startDate)
        let releaseHighlight = highlight.releasing(
            at: startDate.addingTimeInterval(QrCodeViewLayout.tapHighlightAnimationDuration / 2)
        )

        XCTAssertEqual(
            highlight.progress(at: startDate.addingTimeInterval(-1)),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            highlight.progress(at: startDate.addingTimeInterval(1)),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            releaseHighlight.progress(at: startDate.addingTimeInterval(1)),
            0,
            accuracy: 0.0001
        )
    }

    func testUpdatingOriginDoesNotRestartPressAnimation() {
        let highlight = QrCodeTapHighlight(origin: origin, date: startDate)
        let updateDate = startDate.addingTimeInterval(QrCodeViewLayout.tapHighlightAnimationDuration / 2)
        let updatedOrigin = CGPoint(x: 48, y: 56)
        let updatedHighlight = highlight.pressing(
            at: updateDate,
            origin: updatedOrigin
        )

        XCTAssertEqual(updatedHighlight.origin, updatedOrigin)
        XCTAssertEqual(
            updatedHighlight.progress(at: updateDate),
            highlight.progress(at: updateDate),
            accuracy: 0.0001
        )
        XCTAssertEqual(
            updatedHighlight.progress(at: startDate.addingTimeInterval(QrCodeViewLayout.tapHighlightAnimationDuration)),
            1,
            accuracy: 0.0001
        )
    }
}
