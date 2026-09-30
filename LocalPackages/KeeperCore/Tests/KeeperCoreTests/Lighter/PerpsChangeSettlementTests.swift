@testable import KeeperCore
import XCTest

final class PerpsChangeSettlementTests: XCTestCase {
    func testSizeMovesOnlyPastTheBaselineInTheRequestedDirection() {
        XCTAssertTrue(PerpsChangeSettlement.sizeMoved(current: 0.009, before: 0.008, direction: .add))
        XCTAssertFalse(PerpsChangeSettlement.sizeMoved(current: 0.008, before: 0.008, direction: .add))
        XCTAssertFalse(PerpsChangeSettlement.sizeMoved(current: 0.007, before: 0.008, direction: .add))
        XCTAssertTrue(PerpsChangeSettlement.sizeMoved(current: 0.007, before: 0.008, direction: .reduce))
        XCTAssertFalse(PerpsChangeSettlement.sizeMoved(current: 0.008, before: 0.008, direction: .reduce))
    }

    func testSizeChangeRequiresTheRequestedDelta() {
        XCTAssertFalse(
            PerpsChangeSettlement.sizeMoved(
                current: 0.0085,
                before: 0.008,
                direction: .add,
                expectedDelta: 0.001
            )
        )
        XCTAssertTrue(
            PerpsChangeSettlement.sizeMoved(
                current: 0.009,
                before: 0.008,
                direction: .add,
                expectedDelta: 0.001
            )
        )
    }

    func testCloseConfirmsAnyRealPartialReduction() {
        XCTAssertTrue(PerpsChangeSettlement.closeMoved(current: 0.004, before: 0.008))
        XCTAssertFalse(PerpsChangeSettlement.closeMoved(current: 0.008, before: 0.008))
        XCTAssertFalse(PerpsChangeSettlement.closeMoved(current: 0.009, before: 0.008))
    }

    func testMarginRequiresTheRequestedDeltaWithinWirePrecision() {
        XCTAssertFalse(PerpsChangeSettlement.marginMoved(current: 20.4, before: 20.5, amountUsd: 20, direction: .add))
        XCTAssertFalse(PerpsChangeSettlement.marginMoved(current: 30.5, before: 20.5, amountUsd: 20, direction: .add))
        XCTAssertTrue(PerpsChangeSettlement.marginMoved(current: 40.499999, before: 20.5, amountUsd: 20, direction: .add))
        XCTAssertFalse(PerpsChangeSettlement.marginMoved(current: 10.5, before: 20.5, amountUsd: 20, direction: .reduce))
        XCTAssertTrue(PerpsChangeSettlement.marginMoved(current: 0.500001, before: 20.5, amountUsd: 20, direction: .reduce))
    }
}
