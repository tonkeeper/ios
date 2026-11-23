@testable import App
import KeeperCore
@testable import Perps
import PerpsModels
import XCTest

final class PerpsLiveFormattingTests: XCTestCase {
    func test_percentsHaveNoSpaces() {
        let format = PerpsFormatting.live
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."

        XCTAssertEqual(format.signedPercent(-7.8), "\u{2212}7\(separator)8%")
        XCTAssertEqual(format.signedPercent(12.5), "+12\(separator)5%")
        XCTAssertEqual(format.signedPercent(0), "0%")
        XCTAssertEqual(format.funding(percent: 0.0012), "0\(separator)0012%")
        XCTAssertEqual(format.funding(percent: -0.0012), "\u{2212}0\(separator)0012%")
    }

    func test_tradeShelfChangeMatchesPerpsMarketList() {
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."
        let market = PerpsMarketSummary(
            marketId: 1,
            symbol: "BTC",
            name: "Bitcoin",
            iconURL: nil,
            maxLeverage: 50,
            price: 100_000,
            priceChangePercent: -1.89,
            volume24h: 0
        )
        let item = PerpsShelfMarketMapping.item(
            from: market,
            itemsMapper: TradeItemsMapper(
                multichainEnabled: true,
                signedAmountFormatter: AmountFormatter(configuration: .init(signPolicy: .always))
            )
        )

        XCTAssertEqual(item.changeText, "\u{2212}1\(separator)89%")
    }

    @MainActor
    func test_withdrawConfirmationShowsTheQuotedMinimumInTheWalletBalanceStyle() throws {
        let separator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."
        let viewModel = PerpsWithdrawConfirmViewModel(
            reviewed: PerpsReviewedWithdraw(
                terms: PerpsWithdrawTerms(
                    withdrawAmount: "2",
                    receiveAmount: "0.002852063668345678",
                    receivesAtLeast: true,
                    receiveSymbol: "BNB",
                    networkFee: "0.0539",
                    networkFeeSymbol: "USDC"
                ),
                pay: { _ in "op" }
            ),
            destination: PerpsDepositSource(assetId: "bnb", symbol: "BNB", decimals: 18, network: .bsc),
            balance: nil,
            format: .live,
            message: { _ in .failed },
            passcodeProvider: { "0000" }
        )

        let receive = try XCTUnwrap(viewModel.rows.first { $0.id == .youReceive })
        XCTAssertEqual(receive.value, "≥ 0\(separator)00285 BNB")
    }
}
