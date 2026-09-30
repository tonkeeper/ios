@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class TransactionConfirmationTextFormatterTests: XCTestCase {
    /// An EVM withdrawal pays its fee in the chain asset, not in the asset being moved: 18 decimals
    /// over a sub-cent amount used to render as "0 ETH" while the fee was worth up to a dollar.
    func test_tokenFee_underTheDefaultPrecision_keepsItsSignificantDigits() {
        let (topValue, _) = makeFormatter().formatFeeList(
            fee: makeTokenFee(amount: BigUInt(21_000_000_000_000), fractionDigits: 18, symbol: "ETH"),
            rate: nil,
            tonRate: nil,
            currency: .USD
        )
        XCTAssertEqual(topValue, "0.000021 ETH")
    }

    func test_tokenFee_withARate_carriesTheFiatEquivalent() {
        let (_, bottomValue) = makeFormatter().formatFeeList(
            fee: makeTokenFee(amount: BigUInt(21_000_000_000_000), fractionDigits: 18, symbol: "ETH"),
            rate: Rates.Rate(currency: .USD, rate: 4000, diff24h: nil),
            tonRate: nil,
            currency: .USD
        )
        XCTAssertEqual(bottomValue, "$\(String.Symbol.shortSpace)0.084")
    }

    func test_tokenFee_withoutARate_hasNoFiatEquivalent() {
        let (_, bottomValue) = makeFormatter().formatFeeList(
            fee: makeTokenFee(amount: BigUInt(21_000_000_000_000), fractionDigits: 18, symbol: "ETH"),
            rate: nil,
            tonRate: nil,
            currency: .USD
        )
        XCTAssertNil(bottomValue)
    }

    private func makeFormatter() -> TransactionConfirmationTextFormatter {
        TransactionConfirmationTextFormatter(
            amountFormatter: AmountFormatter(configuration: .init())
        )
    }

    private func makeTokenFee(
        amount: BigUInt,
        fractionDigits: Int,
        symbol: String
    ) -> TransactionConfirmationFeeCalculator.FeeDetails {
        TransactionConfirmationFeeCalculator.FeeDetails(
            isRefund: false,
            extraType: .default,
            kind: .token(
                amount: amount,
                fractionDigits: fractionDigits,
                symbol: symbol,
                tokenKind: .other
            )
        )
    }
}
