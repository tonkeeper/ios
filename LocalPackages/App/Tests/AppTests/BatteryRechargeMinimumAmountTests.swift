@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class BatteryRechargeMinimumAmountTests: XCTestCase {
    private let empty = BatteryBalance(balance: "0", reserved: "0")
    private let charged = BatteryBalance(balance: "0.01", reserved: "0")
    private let negative = BatteryBalance(balance: "-0.01", reserved: "0")
    private let gasBalance = BatteryRechargeModel.selfPaidGasTonBalance

    func test_noChargesAndNoTon_requiresMinBootstrapValue() {
        XCTAssertEqual(minimum(battery: empty, ton: 0, min: "0.5"), 500_000)
    }

    func test_unknownOrNegativeBatteryBalance_countsAsNoCharges() {
        XCTAssertEqual(minimum(battery: nil, ton: 0, min: "0.5"), 500_000)
        XCTAssertEqual(minimum(battery: negative, ton: 0, min: "0.5"), 500_000)
    }

    func test_charges_goThroughRelayerWithoutMinimum() {
        XCTAssertNil(minimum(battery: charged, ton: 0, min: "0.5"))
    }

    func test_tonForGas_paysWithoutMinimum() {
        XCTAssertNil(minimum(battery: empty, ton: gasBalance, min: "0.5"))
        XCTAssertEqual(minimum(battery: empty, ton: gasBalance - 1, min: "0.5"), 500_000)
    }

    func test_methodWithoutMinimum_hasNone() {
        XCTAssertNil(minimum(battery: empty, ton: 0, min: nil))
        XCTAssertNil(minimum(battery: empty, ton: 0, min: "0"))
        XCTAssertNil(minimum(battery: empty, ton: 0, min: "abc"))
    }

    func test_minimumRoundsUpToTheTokenUnit() {
        XCTAssertEqual(minimum(battery: empty, ton: 0, min: "0.5000001"), 500_001)
        XCTAssertEqual(minimum(battery: empty, ton: 0, min: "0.0000001"), 1)
    }

    private func minimum(battery: BatteryBalance?, ton: Int64, min: String?) -> BigUInt? {
        BatteryRechargeModel.minimumAmount(
            batteryBalance: battery,
            tonBalance: ton,
            minBootstrapValue: min.map { NSDecimalNumber(string: $0) },
            fractionDigits: 6
        )
    }
}
