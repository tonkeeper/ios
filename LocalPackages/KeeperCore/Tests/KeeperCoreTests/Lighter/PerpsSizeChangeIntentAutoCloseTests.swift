@testable import KeeperCore
import XCTest

final class PerpsSizeChangeIntentAutoCloseTests: XCTestCase {
    private let legs = PerpsAutoClose(
        takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
        stopLoss: PerpsAutoCloseTrigger(triggerPrice: 60000)
    )
    private let otherLegs = PerpsAutoClose(
        takeProfit: PerpsAutoCloseTrigger(triggerPrice: 71000),
        stopLoss: nil
    )
    private let empty = PerpsAutoClose(takeProfit: nil, stopLoss: nil)

    func test_clearOverRestingLegs_cancelsThem() {
        XCTAssertEqual(
            PerpsAutoCloseUpdate(desired: nil, resting: legs),
            .clear
        )
        XCTAssertEqual(PerpsAutoCloseUpdate(desired: empty, resting: legs), .clear)
    }

    func test_clearWithNothingResting_leavesUntouched() {
        XCTAssertEqual(PerpsAutoCloseUpdate(desired: nil, resting: nil), .unchanged)
        XCTAssertEqual(PerpsAutoCloseUpdate(desired: empty, resting: nil), .unchanged)
    }

    func test_editEqualToResting_leavesUntouched() {
        XCTAssertEqual(PerpsAutoCloseUpdate(desired: legs, resting: legs), .unchanged)
    }

    func test_differentEdit_replacesLegs() {
        XCTAssertEqual(PerpsAutoCloseUpdate(desired: otherLegs, resting: legs), .replace(otherLegs))
        XCTAssertEqual(PerpsAutoCloseUpdate(desired: otherLegs, resting: nil), .replace(otherLegs))
    }

    func test_applyingUpdateProducesAbsoluteDesiredState() {
        XCTAssertEqual(PerpsAutoCloseUpdate.unchanged.applying(to: legs), legs)
        XCTAssertNil(PerpsAutoCloseUpdate.clear.applying(to: legs))
        XCTAssertEqual(PerpsAutoCloseUpdate.replace(otherLegs).applying(to: legs), otherLegs)
    }

    func test_intentCanonicalizesEmptyReplacementToClear() {
        let intent = PerpsSizeChangeIntent(
            marketId: 1,
            direction: .reduce,
            marginDeltaUsd: "10",
            autoCloseUpdate: .replace(empty)
        )

        XCTAssertEqual(intent.autoCloseUpdate, .clear)
        XCTAssertNil(PerpsAutoCloseUpdate.replace(empty).applying(to: legs))
    }
}
