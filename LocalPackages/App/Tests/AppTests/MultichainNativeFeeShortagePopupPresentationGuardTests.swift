@testable import App
import XCTest

final class MultichainNativeFeeShortagePopupPresentationGuardTests: XCTestCase {
    func test_reservesOnlyOnePresentationPerFeeCalculation() {
        let presentationGuard = MultichainNativeFeeShortagePopupPresentationGuard()

        XCTAssertTrue(presentationGuard.reservePresentation())
        XCTAssertFalse(presentationGuard.reservePresentation())

        presentationGuard.startNewFeeCalculation()

        XCTAssertTrue(presentationGuard.reservePresentation())
        XCTAssertFalse(presentationGuard.reservePresentation())
    }
}
