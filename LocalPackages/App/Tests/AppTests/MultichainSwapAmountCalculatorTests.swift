@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class MultichainSwapAmountCalculatorTests: XCTestCase {
    /// Max sells the spendable balance. A field string that rounds above that balance still
    /// quotes the balance, and a TON coin keeps its fee reserve.
    func test_maxSendAmountStaysWithinTheSpendableBalance() {
        let calculator = makeCalculator()
        let balance = BigUInt(1_500_000)
        var inputs = makeInputs(
            assetId: "bsc/mainnet/bep20/0xusdt",
            decimals: 6,
            balance: balance,
            amount: "1.500001",
            isMax: true
        )

        XCTAssertEqual(calculator.sourceAmount(inputs: inputs, usdFiatRate: nil), balance)

        inputs = inputs.settingSendAmount("1.5")
        XCTAssertEqual(calculator.sourceAmount(inputs: inputs, usdFiatRate: nil), balance)

        let tonBalance = BigUInt(3_000_000_000)
        let tonInputs = makeInputs(
            assetId: "ton/mainnet/coin",
            decimals: 9,
            balance: tonBalance,
            amount: "3",
            isMax: true
        )
        XCTAssertEqual(
            calculator.sourceAmount(inputs: tonInputs, usdFiatRate: nil),
            tonBalance - 1_000_000_000
        )
    }

    /// The receive field is editable and `swapTokens()` moves its text into the send field, so a
    /// formatted quote has to parse back to the exact base units it was built from.
    func test_formattedAmountRoundTripsThroughInputParser() {
        let calculator = makeCalculator()
        let asset = asset(decimals: 18)

        for baseUnits in [
            "1",
            "123456789012345678",
            "5123456789012345678901234",
        ] {
            let formatted = calculator.formattedAmount(baseUnits, asset: asset)

            XCTAssertEqual(
                calculator.parsedReceiveAmount(text: formatted, asset: asset),
                BigUInt(baseUnits),
                "Round trip lost precision for \(baseUnits) (formatted as \"\(formatted)\")"
            )
        }
    }

    private func makeCalculator() -> MultichainSwapAmountCalculator {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        return MultichainSwapAmountCalculator(
            amountFormatter: AmountFormatter(configuration: configuration),
            displayCurrency: .USD
        )
    }

    private func makeInputs(
        assetId: String,
        decimals: Int,
        balance: BigUInt,
        amount: String,
        isMax: Bool
    ) -> MultichainSwapInputs {
        var inputs = MultichainSwapInputs(
            initialAssets: MultichainSwapInitialAssets(
                sendAsset: asset(assetId: assetId, decimals: decimals, balance: balance),
                receiveAsset: asset(assetId: "ton/mainnet/coin", decimals: 9, balance: 0),
                slippage: nil
            )
        )
        inputs = inputs.settingSendAmount(amount, isMax: isMax)
        return inputs
    }

    private func asset(
        assetId: String = "eth/mainnet/coin",
        decimals: Int,
        balance: BigUInt = .zero
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "asset",
                symbol: "AST",
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:]
            ),
            balance: balance
        )
    }
}
