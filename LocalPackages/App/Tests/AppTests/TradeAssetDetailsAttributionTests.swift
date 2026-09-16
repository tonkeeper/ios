@testable import App
import Foundation
@testable import KeeperCore
import XCTest

@MainActor
final class TradeAssetDetailsAttributionTests: XCTestCase {
    func test_attributionLinksSourceNameToSourceURL() throws {
        let sourceURL = URL(string: "https://dyor.io/token/usdt")
        let text = makeAttributionText(url: sourceURL)
        let linkedRange = try XCTUnwrap(text.range(of: "dyor.io"))

        XCTAssertEqual(text[linkedRange].link, sourceURL)
        XCTAssertTrue(String(text.characters).hasSuffix("dyor.io."))
    }

    func test_attributionStaysPlainTextWithoutSourceURL() {
        let text = makeAttributionText(url: nil)

        XCTAssertNil(text.runs.first { $0.link != nil })
        XCTAssertTrue(String(text.characters).contains("dyor.io"))
    }
}

private extension TradeAssetDetailsAttributionTests {
    func makeAttributionText(url: URL?) -> AttributedString {
        let screen = makeMapper().map(
            details: makeDetails(url: url),
            marketData: nil,
            balance: nil,
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        return screen?.tradingActivity?.attributionText ?? AttributedString()
    }

    func makeMapper() -> TradeAssetDetailsScreenMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")

        return TradeAssetDetailsScreenMapper(
            multichainState: nil,
            preview: TradeAssetDetailsViewModel.PreviewContext(assetID: "ton/mainnet/native"),
            isSwapDisabled: false,
            amountFormatter: AmountFormatter(configuration: configuration),
            signedAmountFormatter: AmountFormatter(configuration: configuration),
            currencyProvider: { .USD }
        )
    }

    func makeDetails(url: URL?) -> TradingAssetDetails {
        TradingAssetDetails(
            id: "ton/mainnet/native",
            assetInfo: TradingAssetInfo(
                assetId: "ton/mainnet/native",
                category: .tokens,
                address: "ton",
                symbol: "TON",
                decimals: 9,
                title: "Toncoin",
                imageURL: nil,
                price: nil,
                changePercent: nil,
                changeAmount: nil,
                earnAPY: nil,
                verification: .whitelist
            ),
            capabilities: [],
            aboutParagraph: "",
            overview: [],
            tradingActivity: TradingAssetTradingActivity(
                volumeText: "1000",
                volumeChangeText: nil,
                buyText: "600",
                sellText: "400",
                buyFraction: 0.6
            ),
            links: [],
            primaryActionTitle: "Buy",
            infoSource: TradingAssetInfoSource(displayedName: "dyor.io", url: url)
        )
    }
}
