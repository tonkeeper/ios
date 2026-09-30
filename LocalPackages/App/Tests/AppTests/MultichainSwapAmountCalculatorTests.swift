@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class MultichainSwapAmountCalculatorTests: XCTestCase {
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

    private func asset(decimals: Int) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "eth/mainnet/coin",
                name: "ETH",
                symbol: "ETH",
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: .zero
        )
    }
}
