@testable import App
import KeeperCore
import XCTest

final class BatteryRefillIAPRefundsTests: XCTestCase {
    func testSingleRefundKeepsInAppPurchasesEnabled() {
        let purchases = [
            purchase(id: 1, kind: .ios, isRefunded: true),
            purchase(id: 2, kind: .ios, isRefunded: false),
        ]

        XCTAssertFalse(BatteryRefillIAPModel.isDisabledByRefunds(purchases: purchases))
    }

    func testSecondRefundDisablesInAppPurchases() {
        let purchases = [
            purchase(id: 1, kind: .ios, isRefunded: true),
            purchase(id: 2, kind: .android, isRefunded: true),
            purchase(id: 3, kind: .crypto, isRefunded: false),
        ]

        XCTAssertTrue(BatteryRefillIAPModel.isDisabledByRefunds(purchases: purchases))
    }

    /// Crypto refunds are a supported flow, not store abuse.
    func testNonStoreRefundsDoNotDisableInAppPurchases() {
        let purchases = [
            purchase(id: 1, kind: .crypto, isRefunded: true),
            purchase(id: 2, kind: .crypto, isRefunded: true),
            purchase(id: 3, kind: .gift, isRefunded: true),
            purchase(id: 4, kind: .promocode, isRefunded: true),
        ]

        XCTAssertFalse(BatteryRefillIAPModel.isDisabledByRefunds(purchases: purchases))
    }

    func testEmptyPurchasesKeepInAppPurchasesEnabled() {
        XCTAssertFalse(BatteryRefillIAPModel.isDisabledByRefunds(purchases: []))
    }

    private func purchase(
        id: Int,
        kind: BatteryPurchase.Kind,
        isRefunded: Bool
    ) -> BatteryPurchase {
        BatteryPurchase(identifier: id, kind: kind, isRefunded: isRefunded)
    }
}
