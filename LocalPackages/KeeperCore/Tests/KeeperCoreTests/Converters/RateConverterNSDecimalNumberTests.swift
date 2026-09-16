import BigInt
@testable import KeeperCore
import XCTest

final class RateConverterNSDecimalNumberTests: XCTestCase {
    private let converter = RateConverter()

    func test_convert_preservesSmallCryptoAmountAcrossFiatScale() throws {
        // $30.00 (2 decimals) → BTC at $100,000/BTC → 0.0003 BTC (8 decimals)
        let sourceAmount = BigUInt(3000)
        let rate = try NSDecimalNumber(decimal: XCTUnwrap(Decimal(string: "0.00001")))

        let converted = converter.convert(
            amount: sourceAmount,
            amountFractionLength: 2,
            rate: rate,
            targetFractionLength: 8
        )

        XCTAssertEqual(converted, BigUInt(30000))
    }

    func test_convert_usdtNearParityKeepsFullAmount() {
        // $30.00 → ~30 USDT (6 decimals) at rate 1
        let converted = converter.convert(
            amount: BigUInt(3000),
            amountFractionLength: 2,
            rate: NSDecimalNumber(value: 1),
            targetFractionLength: 6
        )

        XCTAssertEqual(converted, BigUInt(30_000_000))
    }

    func test_convert_ethBelowOneCentDisplayThreshold() throws {
        // $30.00 → 0.0075 ETH (9 decimals) when ETH is $4,000
        let rate = try NSDecimalNumber(decimal: XCTUnwrap(Decimal(string: "0.00025")))
        let converted = converter.convert(
            amount: BigUInt(3000),
            amountFractionLength: 2,
            rate: rate,
            targetFractionLength: 9
        )

        XCTAssertEqual(converted, BigUInt(7_500_000))
    }

    func test_convertFromCurrency_roundTripsSmallBTCAmount() throws {
        let rate = try NSDecimalNumber(decimal: XCTUnwrap(Decimal(string: "0.00001")))
        let btcAmount = BigUInt(30000) // 0.0003 BTC

        let fiat = converter.convertFromCurrency(
            amount: btcAmount,
            amountFractionLength: 8,
            rate: rate,
            targetFractionLength: 2
        )

        XCTAssertEqual(fiat, BigUInt(3000))
    }

    func test_convert_sameFractionLengthMatchesLegacyMultiplyTruncate() {
        // When scales match, result equals trunc(amount * rate)
        let converted = converter.convert(
            amount: BigUInt(1_000_000_000),
            amountFractionLength: 9,
            rate: NSDecimalNumber(value: 5),
            targetFractionLength: 9
        )

        XCTAssertEqual(converted, BigUInt(5_000_000_000))
    }
}
