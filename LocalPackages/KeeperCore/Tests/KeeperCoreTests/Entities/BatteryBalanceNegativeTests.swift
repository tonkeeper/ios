import Foundation
@testable import KeeperCore
import XCTest

final class BatteryBalanceNegativeTests: XCTestCase {
    func testRefundedBalanceIsNegative() {
        let balance = BatteryBalance(balance: "-0.3276", reserved: "0")

        XCTAssertTrue(balance.isBalanceNegative)
        XCTAssertFalse(balance.isBalanceZero)
        XCTAssertEqual(balance.batteryState, .negative)
        XCTAssertEqual(balance.batteryState.percents, 0)
    }

    func testZeroBalanceIsEmpty() {
        let balance = BatteryBalance.empty

        XCTAssertFalse(balance.isBalanceNegative)
        XCTAssertEqual(balance.batteryState, .empty)
    }

    func testPositiveBalanceKeepsFillState() {
        let balance = BatteryBalance(balance: "2", reserved: "0")

        XCTAssertFalse(balance.isBalanceNegative)
        XCTAssertEqual(balance.batteryState, .fill(percents: 0.5))
    }

    /// A malformed balance must not read as a refund.
    func testUnparsableBalanceIsEmpty() {
        let balance = BatteryBalance(balance: "", reserved: "0")

        XCTAssertFalse(balance.isBalanceNegative)
        XCTAssertEqual(balance.batteryState, .empty)
    }
}
