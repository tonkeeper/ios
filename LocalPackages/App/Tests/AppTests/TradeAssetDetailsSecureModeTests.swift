@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKUIKit
import TronSwift
import XCTest

@MainActor
final class TradeAssetDetailsSecureModeTests: XCTestCase {
    func test_balanceSectionShowsAmountsWhenSecureModeIsOff() {
        let screen = makeScreen(isSecureMode: false)

        XCTAssertEqual(screen?.balance?.amountText, "7.18\u{2009}\(TronSwift.USDT.symbol)")
        XCTAssertEqual(screen?.balance?.convertedAmountText, "$\u{2009}7.18")
    }

    func test_balanceSectionMasksAmountsInSecureMode() {
        let screen = makeScreen(isSecureMode: true)

        XCTAssertEqual(screen?.balance?.amountText, String.secureModeValueShort)
        XCTAssertEqual(screen?.balance?.convertedAmountText, String.secureModeValueShort)
    }

    /// Market data belongs to the asset, not to the wallet, so secure mode leaves it readable.
    func test_marketDataStaysVisibleInSecureMode() {
        let screen = makeScreen(isSecureMode: true)

        XCTAssertEqual(screen?.priceText, makeScreen(isSecureMode: false)?.priceText)
        XCTAssertEqual(screen?.changeText, makeScreen(isSecureMode: false)?.changeText)
    }

    func test_legacyHistoryMasksAmountsInSecureMode() {
        let screen = makeScreen(
            isSecureMode: true,
            history: TradeAssetDetailsHistorySectionViewData(
                items: [
                    TradeAssetDetailsHistoryItemViewData(
                        id: "event",
                        icon: .init(image: .TKUIKit.Icons.Size28.trayArrowDown),
                        title: "Received",
                        subtitle: "EQCx…6mU",
                        amountText: "+7.18 USDT",
                        amountStyle: .positive,
                        dateText: "12:00"
                    ),
                ]
            )
        )

        XCTAssertEqual(screen?.history?.items.map(\.amountText), [String.secureModeValueShort])
        XCTAssertEqual(screen?.history?.items.map(\.title), ["Received"])
    }

    func test_multichainHistoryMasksAmountsInSecureMode() {
        let screen = makeScreen(
            isSecureMode: true,
            multichainHistory: TradeAssetDetailsMultichainHistorySectionViewData(
                items: [makeMultichainItem()]
            )
        )
        let item = screen?.multichainHistory?.items.first

        XCTAssertEqual(item?.primaryAmount?.text, String.secureModeValueShort)
        XCTAssertEqual(item?.secondaryAmount?.text, String.secureModeValueShort)
        XCTAssertEqual(item?.primaryAmount?.chainTitle, "TRX")
        XCTAssertEqual(item?.title, "Swapped")
    }

    func test_multichainHistoryKeepsAmountsWhenSecureModeIsOff() {
        let screen = makeScreen(
            isSecureMode: false,
            multichainHistory: TradeAssetDetailsMultichainHistorySectionViewData(
                items: [makeMultichainItem()]
            )
        )

        XCTAssertEqual(screen?.multichainHistory?.items.first?.primaryAmount?.text, "+7.18 USDT")
    }
}

private extension TradeAssetDetailsSecureModeTests {
    var tronUsdtAssetId: String {
        "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
    }

    func makeScreen(
        isSecureMode: Bool,
        history: TradeAssetDetailsHistorySectionViewData? = nil,
        multichainHistory: TradeAssetDetailsMultichainHistorySectionViewData? = nil
    ) -> TradeAssetDetailsScreenViewData? {
        makeMapper().map(
            details: makeDetails(),
            marketData: nil,
            balance: makeSnapshot(),
            history: history,
            multichainHistory: multichainHistory,
            tronFees: nil,
            isSecureMode: isSecureMode
        ).screen
    }

    func makeMapper() -> TradeAssetDetailsScreenMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = "\u{2009}"
        var signedConfiguration = configuration
        signedConfiguration.signPolicy = .always

        return TradeAssetDetailsScreenMapper(
            multichainState: MultichainWalletState(
                walletId: "multichain",
                addresses: [
                    MultichainWalletAddress(chain: .tron, address: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"),
                ]
            ),
            preview: TradeAssetDetailsViewModel.PreviewContext(assetID: tronUsdtAssetId),
            isSwapDisabled: false,
            amountFormatter: AmountFormatter(configuration: configuration),
            signedAmountFormatter: AmountFormatter(configuration: signedConfiguration),
            currencyProvider: { .USD }
        )
    }

    func makeSnapshot() -> TradeAssetDetailsBalanceSnapshot {
        TradeAssetDetailsBalanceSnapshot(
            symbol: TronSwift.USDT.symbol,
            imageURL: nil,
            amount: 7_180_000,
            fractionDigits: TronSwift.USDT.fractionDigits,
            convertedAmount: 7.18,
            tagText: TronSwift.USDT.tag,
            freshness: .actual
        )
    }

    func makeDetails() -> TradingAssetDetails {
        TradingAssetDetails(
            id: tronUsdtAssetId,
            assetInfo: TradingAssetInfo(
                assetId: tronUsdtAssetId,
                category: .tokens,
                address: TronSwift.USDT.address.base58,
                symbol: TronSwift.USDT.symbol,
                decimals: TronSwift.USDT.fractionDigits,
                title: TronSwift.USDT.name,
                imageURL: nil,
                price: 1,
                changePercent: 2,
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
            infoSource: TradingAssetInfoSource(
                displayedName: "coinmarketcap.com",
                url: nil
            )
        )
    }

    func makeMultichainItem() -> MultichainHistoryActivityItem {
        let activity = makeActivity()
        return MultichainHistoryActivityItem(
            id: MultichainHistoryActivityIdentity(activity: activity),
            activity: activity,
            title: "Swapped",
            subtitle: nil,
            comment: nil,
            time: "12:00",
            icon: .TKUIKit.Icons.Size28.trayArrowDown,
            primaryAmount: MultichainHistoryActivityItem.Amount(
                text: "+7.18 USDT",
                chainTitle: "TRX",
                style: .positive
            ),
            secondaryAmount: MultichainHistoryActivityItem.Amount(
                text: "−1 TON",
                chainTitle: "TON",
                style: .negative
            ),
            status: .confirmed,
            nft: nil
        )
    }

    func makeActivity() -> MultichainActivity {
        MultichainActivity(
            activityType: .swap,
            status: .confirmed,
            blockTime: Date(timeIntervalSince1970: 0),
            blockNumber: nil,
            fromChain: .tron,
            toChain: .tron,
            walletAddress: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
            direction: .selfTransfer,
            fromAddress: nil,
            toAddress: nil,
            outToken: nil,
            outAmount: nil,
            outAmountUsd: nil,
            inToken: nil,
            inAmount: nil,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: ["tron:hash"],
            isRead: nil
        )
    }
}
