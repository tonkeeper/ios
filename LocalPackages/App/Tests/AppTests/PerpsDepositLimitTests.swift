@testable import App
import Foundation
import XCTest

final class PerpsDepositLimitTests: XCTestCase {
    @MainActor
    func testBitcoinFallsBackWhenFullBalanceCannotProducePSBT() async throws {
        var requests = [Decimal]()
        let limit = await PerpsLiveDeposit.nativeLimit(balance: 1, decimals: 8) { amount in
            let value = Decimal(string: amount)!
            requests.append(value)
            return value == 1 ? nil : Decimal(string: "0.001")!
        }
        XCTAssertEqual(limit, "0.99875")
        XCTAssertEqual(requests, try [1, XCTUnwrap(Decimal(string: "0.9")), XCTUnwrap(Decimal(string: "0.99875"))])
    }

    @MainActor
    func testBitcoinProbesUseWholeSatoshisForAnOddBalance() async throws {
        let satoshi = try XCTUnwrap(Decimal(string: "0.00000001"))
        let balance = 3859 * satoshi
        let fee = 780 * satoshi
        var requests = [String]()

        let limit = await PerpsLiveDeposit.nativeLimit(balance: balance, decimals: 8) { amount in
            requests.append(amount)
            let parts = amount.split(separator: ".")
            guard parts.count < 2 || parts[1].count <= 8 else { return nil }
            let value = Decimal(string: amount)!
            return value + fee <= balance ? fee : nil
        }

        XCTAssertEqual(limit, (2884 * satoshi).description)
        XCTAssertTrue(requests.allSatisfy { amount in
            let parts = amount.split(separator: ".")
            return parts.count < 2 || parts[1].count <= 8
        })
    }

    @MainActor
    func testBitcoinProbesSkipZeroAndDuplicateAmounts() async throws {
        let satoshi = try XCTUnwrap(Decimal(string: "0.00000001"))
        for (units, expected) in [(0, []), (1, [1]), (2, [2, 1])] {
            var requests = [Decimal]()
            let limit = await PerpsLiveDeposit.nativeLimit(balance: Decimal(units) * satoshi, decimals: 8) { amount in
                requests.append(Decimal(string: amount)! / satoshi)
                return nil
            }
            XCTAssertNil(limit)
            XCTAssertEqual(requests, expected.map { Decimal($0) })
        }
    }

    /// 4270 sats held, but the payment spends one 3654-sat output and pays 570 of it as the fee.
    @MainActor
    func testBitcoinMaxSettlesOnAPayableAmountWhenOutputsCannotCoverTheBalance() async throws {
        let sats = try XCTUnwrap(Decimal(string: "0.00000001"))
        let fee = 570 * sats
        let limit = await PerpsLiveDeposit.nativeLimit(balance: 4270 * sats, decimals: 8) { amount in
            let value = Decimal(string: amount)!
            return value + fee <= 3654 * sats ? fee : nil
        }
        XCTAssertEqual(limit, (3023 * sats).description)
    }

    @MainActor
    func testTronLimitReservesFeeAndRoundsDownToAssetPrecision() async {
        let limit = await PerpsLiveDeposit.nativeLimit(balance: 100, decimals: 6) { _ in Decimal(string: "1.1234567") }
        XCTAssertEqual(limit, "98.595679")
    }

    @MainActor
    func testChangedBitcoinInputSelectionIsRepriced() async {
        var requests = 0
        let limit = await PerpsLiveDeposit.nativeLimit(balance: 1, decimals: 8) { _ in
            requests += 1
            return requests == 1 ? Decimal(string: "0.001") : Decimal(string: "0.01")
        }
        XCTAssertEqual(limit, "0.9875")
        XCTAssertEqual(requests, 3)
    }
}
