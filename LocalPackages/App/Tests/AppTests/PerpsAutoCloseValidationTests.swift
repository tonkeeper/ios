@testable import App
import KeeperCore
import XCTest

final class PerpsAutoCloseValidationTests: XCTestCase {
    func test_long_takeProfitBelowMark_isInvalid() {
        let invalid = PerpsAutoCloseValidation.invalidLegs(
            side: .long,
            referencePrice: 66000,
            liquidationPrice: 50000,
            takeProfitPrice: 59500,
            stopLossPrice: 49700
        )
        XCTAssertTrue(invalid.takeProfit)
        XCTAssertTrue(invalid.stopLoss)
        XCTAssertEqual(
            PerpsAutoCloseValidation.confirmStaleKind(
                side: .long,
                referencePrice: 66000,
                liquidationPrice: 50000,
                autoClose: PerpsAutoClose(
                    takeProfit: PerpsAutoCloseTrigger(triggerPrice: 59500),
                    stopLoss: PerpsAutoCloseTrigger(triggerPrice: 49700)
                )
            ),
            .autoClose
        )
    }

    func test_long_onlyTakeProfitStale_kindIsTakeProfit() {
        let kind = PerpsAutoCloseValidation.confirmStaleKind(
            side: .long,
            referencePrice: 70000,
            liquidationPrice: 50000,
            autoClose: PerpsAutoClose(
                takeProfit: PerpsAutoCloseTrigger(triggerPrice: 68000),
                stopLoss: PerpsAutoCloseTrigger(triggerPrice: 55000)
            )
        )
        XCTAssertEqual(kind, .takeProfit)
    }

    func test_long_onlyStopLossStale_kindIsStopLoss() {
        let kind = PerpsAutoCloseValidation.confirmStaleKind(
            side: .long,
            referencePrice: 60000,
            liquidationPrice: 50000,
            autoClose: PerpsAutoClose(
                takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
                stopLoss: PerpsAutoCloseTrigger(triggerPrice: 61000)
            )
        )
        XCTAssertEqual(kind, .stopLoss)
    }

    func test_stripping_removesOnlyInvalidLegs() {
        let autoClose = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 68000),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 55000)
        )
        let invalid = PerpsAutoCloseValidation.InvalidLegs(takeProfit: true, stopLoss: false)
        let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
        XCTAssertNil(stripped.takeProfit)
        XCTAssertEqual(stripped.stopLoss?.triggerPrice, 55000)
    }

    func test_short_markPastTakeProfit_isInvalid() {
        let kind = PerpsAutoCloseValidation.confirmStaleKind(
            side: .short,
            referencePrice: 60000,
            liquidationPrice: 70000,
            autoClose: PerpsAutoClose(
                takeProfit: PerpsAutoCloseTrigger(triggerPrice: 62000),
                stopLoss: nil
            )
        )
        XCTAssertEqual(kind, .takeProfit)
    }
}
