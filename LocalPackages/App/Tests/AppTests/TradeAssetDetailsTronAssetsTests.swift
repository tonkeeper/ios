@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKLocalize
import TKUIKit
import TronSwift
import XCTest

final class TradeAssetDetailsTronAssetsTests: XCTestCase {
    func test_tradingAssetToken_resolvesTronCoinAsTrx() {
        guard case .tronTrx = TradingAssetToken(assetId: trxAssetId) else {
            return XCTFail("expected tron coin to resolve as TRX")
        }
    }

    @MainActor
    func test_mapper_forLegacyTrx_showsSend() {
        let screen = makeMapper(assetId: trxAssetId, multichainState: nil).map(
            details: makeDetails(assetId: trxAssetId),
            marketData: nil,
            balance: makeSnapshot(amount: 12_000_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.isSendAvailable, true)
        XCTAssertEqual(screen?.actionButtons, [.send, .receive])
        XCTAssertEqual(screen?.actionBarState, .buySell)
    }

    @MainActor
    func test_mapper_forLegacyTrxWithoutBalance_hidesSend() {
        let screen = makeMapper(assetId: trxAssetId, multichainState: nil).map(
            details: makeDetails(assetId: trxAssetId),
            marketData: nil,
            balance: makeSnapshot(amount: 0),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.isSendAvailable, false)
        XCTAssertEqual(screen?.actionButtons, [.receive])
    }

    func test_tronSendItem_keepsItsToken() {
        XCTAssertEqual(TronSendData.Item.trx(amount: 5).token, .trx)
        XCTAssertEqual(TronSendData.Item.trx(amount: 5).amount, 5)
        XCTAssertEqual(TronSendData.Item.trx(amount: 5).settingAmount(7).amount, 7)
        XCTAssertEqual(TronSendData.Item.trx(amount: 5).settingAmount(7).token, .trx)
        XCTAssertEqual(TronSendData.Item.usdt(amount: 5).settingAmount(7).token, .usdt)
    }

    func test_trxToken_sendItemIsNotRewrittenToUsdt() {
        guard case let .tron(item) = KeeperCore.Token.tron(.trx).sendV3Item else {
            return XCTFail("expected a tron send item")
        }
        XCTAssertEqual(item.token, .trx)
    }

    @MainActor
    func test_mapper_forMultichainTrx_keepsSend() {
        let screen = makeMapper(assetId: trxAssetId).map(
            details: makeDetails(assetId: trxAssetId),
            marketData: nil,
            balance: makeSnapshot(amount: 12_000_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.isSendAvailable, true)
        XCTAssertEqual(screen?.actionButtons, [.send, .receive])
    }

    @MainActor
    func test_mapper_forLegacyTronUsdt_keepsSend() {
        let screen = makeMapper(assetId: tronUsdtAssetId, multichainState: nil).map(
            details: makeDetails(assetId: tronUsdtAssetId),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.isSendAvailable, true)
        XCTAssertEqual(screen?.actionButtons, [.send, .receive])
    }

    @MainActor
    func test_mapper_withoutFeesForAnyTransfer_inTrxOnlyRegion_showsGetTrxBanner() {
        let screen = makeScreen(tronFees: makeSnapshot(isTRXOnlyRegion: true, trxBalance: 0))

        guard case let .banner(banner) = screen?.tronFees else {
            return XCTFail("expected a banner")
        }
        XCTAssertEqual(banner.style, .trx)
        XCTAssertEqual(banner.buttonTitle, TKLocales.TronUsdtFees.Common.Buttons.getTrx)
        XCTAssertEqual(banner.title, TKLocales.TronUsdtFees.TokenDetails.Banners.TrxInsufficient.title)
    }

    @MainActor
    func test_mapper_withoutFeesForAnyTransfer_showsFeeOptionsBanner() {
        let screen = makeScreen(tronFees: makeSnapshot(isTRXOnlyRegion: false, trxBalance: 0))

        guard case let .banner(banner) = screen?.tronFees else {
            return XCTFail("expected a banner")
        }
        XCTAssertEqual(banner.style, .battery)
        XCTAssertEqual(banner.buttonTitle, TKLocales.TronUsdtFees.Common.Buttons.allFeeOptions)
        XCTAssertEqual(banner.title, TKLocales.TronUsdtFees.TokenDetails.Banners.FeeOptionsInsufficient.title)
    }

    @MainActor
    func test_mapper_withFeesForTransfers_showsTransfersAvailable() {
        let screen = makeScreen(
            tronFees: makeSnapshot(isTRXOnlyRegion: true, trxBalance: 30_000_000)
        )

        XCTAssertEqual(
            screen?.tronFees,
            .transfersAvailable(TKLocales.TronUsdtFees.TokenDetails.transferAvailability(3))
        )
    }

    @MainActor
    func test_mapper_withoutFeesSnapshot_showsNoFeesSection() {
        XCTAssertNil(makeScreen(tronFees: nil)?.tronFees)
    }
}

private extension TradeAssetDetailsTronAssetsTests {
    var trxAssetId: String {
        "tron/mainnet/coin"
    }

    var tronUsdtAssetId: String {
        "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
    }

    @MainActor
    func makeScreen(tronFees: TronUsdtFeesSnapshot?) -> TradeAssetDetailsScreenViewData? {
        makeMapper(assetId: tronUsdtAssetId, multichainState: nil).map(
            details: makeDetails(assetId: tronUsdtAssetId),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: tronFees,
            isSecureMode: false
        ).screen
    }

    @MainActor
    func makeMapper(
        assetId: String,
        multichainState: MultichainWalletState? = MultichainWalletState(
            walletId: "multichain",
            addresses: [
                MultichainWalletAddress(chain: .tron, address: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"),
            ]
        )
    ) -> TradeAssetDetailsScreenMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = "\u{2009}"
        var signedConfiguration = configuration
        signedConfiguration.signPolicy = .always

        return TradeAssetDetailsScreenMapper(
            multichainState: multichainState,
            preview: TradeAssetDetailsViewModel.PreviewContext(assetID: assetId),
            isSwapDisabled: false,
            amountFormatter: AmountFormatter(configuration: configuration),
            signedAmountFormatter: AmountFormatter(configuration: signedConfiguration),
            currencyProvider: { .USD }
        )
    }

    func makeSnapshot(amount: BigUInt) -> TradeAssetDetailsBalanceSnapshot {
        TradeAssetDetailsBalanceSnapshot(
            symbol: TronSwift.TRX.symbol,
            imageURL: nil,
            amount: amount,
            fractionDigits: TronSwift.TRX.fractionDigits,
            convertedAmount: 1.2,
            tagText: nil,
            freshness: .actual
        )
    }

    func makeSnapshot(
        isTRXOnlyRegion: Bool,
        trxBalance: BigUInt
    ) -> TronUsdtFeesSnapshot {
        TronUsdtFeesSnapshot(
            isTRXOnlyRegion: isTRXOnlyRegion,
            requiredTRX: 10_000_000,
            trxBalance: trxBalance,
            requiredBatteryCharges: 4,
            batteryChargesBalance: 0,
            batteryFillPercent: 0,
            requiredTON: 100_000_000,
            tonBalance: 0
        )
    }

    func makeDetails(assetId: String) -> TradingAssetDetails {
        TradingAssetDetails(
            id: assetId,
            assetInfo: TradingAssetInfo(
                assetId: assetId,
                category: .tokens,
                address: "",
                symbol: TronSwift.TRX.symbol,
                decimals: TronSwift.TRX.fractionDigits,
                title: TronSwift.TRX.name,
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
            infoSource: TradingAssetInfoSource(
                displayedName: "coinmarketcap.com",
                url: nil
            )
        )
    }
}
