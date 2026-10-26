@testable import App
import Foundation
@testable import KeeperCore
@testable import Perps
import TKLocalize
import XCTest

@MainActor
final class TradeAssetDetailsPerpPositionMappingTests: XCTestCase {
    func test_assetWithPerpMarketAndNoPosition_showsTheBanner() {
        let details = makeDetails(perpMarket: TradingAssetPerpMarket(marketId: 3, maxLeverage: 10))

        let section = makeScreen(details: details, state: .noPosition)?.perpPosition

        guard case let .banner(marketId, title, caption) = section else { return XCTFail("expected banner") }
        XCTAssertEqual(marketId, 3)
        XCTAssertEqual(title, TKLocales.Trade.AssetDetails.PerpPosition.tradeTitle("GRAM"))
        XCTAssertEqual(caption, TKLocales.Trade.AssetDetails.PerpPosition.leverageCaption("10x"))
    }

    func test_assetWithPerpMarketAndOpenPosition_showsThePositionRow() {
        let details = makeDetails(perpMarket: TradingAssetPerpMarket(marketId: 3, maxLeverage: nil))
        let row = PerpsPositionRowItem(
            id: 3,
            symbol: "GRAM",
            iconURL: nil,
            leverageText: "27X",
            sideText: "LONG",
            isLong: true,
            valueText: "$20.50",
            pnlText: "+$0.50",
            isPnlPositive: true
        )

        let section = makeScreen(details: details, state: .position(row))?.perpPosition

        guard case let .position(mapped) = section else { return XCTFail("expected position") }
        XCTAssertEqual(mapped, row)
    }

    func test_bannerWithoutLeverage_hasNoCaption() {
        let details = makeDetails(perpMarket: TradingAssetPerpMarket(marketId: 3, maxLeverage: nil))

        guard case let .banner(_, _, caption) = makeScreen(details: details, state: .noPosition)?.perpPosition else {
            return XCTFail("expected banner")
        }
        XCTAssertNil(caption)
    }

    func test_loadingAccount_showsTheSkeleton() {
        let details = makeDetails(perpMarket: TradingAssetPerpMarket(marketId: 3, maxLeverage: 10))

        guard case .loading = makeScreen(details: details, state: .loading)?.perpPosition else {
            return XCTFail("expected skeleton")
        }
    }

    func test_assetWithoutPerpMarket_hasNoSection() {
        let details = makeDetails(perpMarket: nil)

        XCTAssertNil(makeScreen(details: details, state: .noPosition)?.perpPosition)
    }
}

private extension TradeAssetDetailsPerpPositionMappingTests {
    func makeDetails(perpMarket: TradingAssetPerpMarket?) -> TradingAssetDetails {
        TradingAssetDetails(
            id: "ton/mainnet/coin",
            assetInfo: TradingAssetInfo(
                assetId: "ton/mainnet/coin",
                category: .tokens,
                address: "coin",
                symbol: "GRAM",
                decimals: 9,
                title: "Gram",
                imageURL: nil,
                price: nil,
                changePercent: nil,
                changeAmount: nil,
                earnAPY: nil,
                verification: .whitelist
            ),
            capabilities: [.swap],
            aboutParagraph: "",
            overview: [],
            tradingActivity: nil,
            links: [],
            primaryActionTitle: "Buy",
            infoSource: TradingAssetInfoSource(displayedName: "dyor.io", url: nil),
            perpMarket: perpMarket
        )
    }

    func makeScreen(
        details: TradingAssetDetails,
        state: TradeAssetDetailsPerpPositionViewModel.State
    ) -> TradeAssetDetailsScreenViewData? {
        TradeAssetDetailsScreenMapper(
            multichainState: MultichainWalletState(walletId: "multichain", addresses: []),
            preview: TradeAssetDetailsViewModel.PreviewContext(assetID: details.id),
            isSwapDisabled: false,
            amountFormatter: AmountFormatter(configuration: AmountFormatter.Configuration()),
            signedAmountFormatter: AmountFormatter(configuration: AmountFormatter.Configuration()),
            currencyProvider: { .USD }
        ).map(
            details: details,
            marketData: nil,
            balance: nil,
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            perpPosition: state,
            isSecureMode: false
        ).screen
    }
}
