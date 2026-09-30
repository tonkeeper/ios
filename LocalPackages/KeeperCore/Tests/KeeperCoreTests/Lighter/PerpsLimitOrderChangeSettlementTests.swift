@testable import KeeperCore
import XCTest

final class PerpsLimitOrderChangeSettlementTests: XCTestCase {
    func testActiveModifyConfirmsOnlyAtTheNormalizedTargetPrice() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .modify, limitPrice: 67250.12)

        XCTAssertTrue(PerpsLimitOrderChangeSettlement.activeOrderConfirms(change: change, price: 67250.12))
        XCTAssertFalse(PerpsLimitOrderChangeSettlement.activeOrderConfirms(change: change, price: 67000))
    }

    func testActiveCancelNeverConfirmsFromPresence() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)

        XCTAssertFalse(PerpsLimitOrderChangeSettlement.activeOrderConfirms(change: change, price: 67250.12))
    }
}
