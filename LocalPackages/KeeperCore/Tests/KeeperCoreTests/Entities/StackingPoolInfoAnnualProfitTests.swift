import BigInt
import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class StackingPoolInfoAnnualProfitTests: XCTestCase {
    private let oneTon = BigUInt(1_000_000_000)

    func testFractionalAPYKeepsNanotonPrecision() throws {
        let pool = try makePool(apy: XCTUnwrap(Decimal(string: "13.73")))

        XCTAssertEqual(pool.annualProfit(for: oneTon), BigUInt(137_300_000))
    }

    func testWholeAPYWithZeroExponent() {
        let pool = makePool(apy: 5)

        XCTAssertEqual(pool.annualProfit(for: oneTon), BigUInt(50_000_000))
    }

    func testZeroAmountEarnsNothing() throws {
        let pool = try makePool(apy: XCTUnwrap(Decimal(string: "13.73")))

        XCTAssertEqual(pool.annualProfit(for: 0), 0)
    }

    func testZeroAPYEarnsNothing() {
        let pool = makePool(apy: 0)

        XCTAssertEqual(pool.annualProfit(for: oneTon), 0)
    }

    func testScalesLinearlyWithAmount() throws {
        let pool = try makePool(apy: XCTUnwrap(Decimal(string: "4.7891")))

        XCTAssertEqual(pool.annualProfit(for: oneTon * 1000), pool.annualProfit(for: oneTon) * 1000)
    }

    func testSubNanotonRewardTruncatesToZero() throws {
        let pool = try makePool(apy: XCTUnwrap(Decimal(string: "0.01")))

        XCTAssertEqual(pool.annualProfit(for: 99), 0)
    }

    private func makePool(apy: Decimal) -> StackingPoolInfo {
        StackingPoolInfo(
            address: try! Address.parse(raw: "0:0000000000000000000000000000000000000000000000000000000000000000"),
            name: "Pool",
            totalAmount: 0,
            implementation: StackingPoolInfo.Implementation(
                type: .liquidTF,
                name: "Tonstakers",
                description: "",
                urlString: "",
                socials: []
            ),
            apy: apy,
            minStake: 0,
            cycleStart: 0,
            cycleEnd: 0,
            isVerified: true,
            currentNominators: 0,
            maxNominators: 0,
            liquidJettonMaster: nil,
            nominatorsStake: 0,
            validatorStake: 0,
            cycleLength: nil
        )
    }
}
