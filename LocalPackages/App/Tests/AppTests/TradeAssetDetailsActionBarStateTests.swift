@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKUIKit
import TronSwift
import XCTest

final class TradeAssetDetailsActionBarStateTests: XCTestCase {
    func test_withoutSwapCapability_hidesBothActions() {
        XCTAssertEqual(
            TradeAssetDetailsActionBarState(supportsSwap: false, hasBalance: true),
            .none
        )
    }

    func test_withoutBalance_showsBuyOnly() {
        XCTAssertEqual(
            TradeAssetDetailsActionBarState(supportsSwap: true, hasBalance: false),
            .buy
        )
    }

    func test_withBalance_showsBuyAndSell() {
        XCTAssertEqual(
            TradeAssetDetailsActionBarState(supportsSwap: true, hasBalance: true),
            .buySell
        )
    }

    @MainActor
    func test_mapper_withTronUsdtBalance_enablesSendAndSell() {
        let screen = makeMapper().map(
            details: makeTronUsdtDetails(),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertNotNil(screen?.balance)
        XCTAssertEqual(screen?.isSendAvailable, true)
        XCTAssertEqual(screen?.actionBarState, .buySell)
        XCTAssertEqual(screen?.actionButtons, [.send, .receive])
    }

    @MainActor
    func test_mapper_withoutTronUsdtBalance_disablesSendAndSell() {
        let screen = makeMapper().map(
            details: makeTronUsdtDetails(),
            marketData: nil,
            balance: nil,
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertNil(screen?.balance)
        XCTAssertEqual(screen?.isSendAvailable, false)
        XCTAssertEqual(screen?.actionBarState, .buy)
        XCTAssertEqual(screen?.actionButtons, [.receive])
    }

    @MainActor
    func test_mapper_withRampCapabilities_showsCashButtons() {
        let screen = makeMapper().map(
            details: makeTronUsdtDetails(capabilities: [.swap, .onramp, .offramp]),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.actionButtons, [.send, .receive, .cashBuy, .cashSell])
    }

    @MainActor
    func test_mapper_withRampCapabilitiesWithoutMultichain_hidesCashButtons() {
        let screen = makeMapper(multichainState: nil).map(
            details: makeTronUsdtDetails(capabilities: [.swap, .onramp, .offramp]),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.actionButtons, [.send, .receive])
    }

    @MainActor
    func test_mapper_withRampCapabilitiesWithoutBalance_hidesCashSell() {
        let screen = makeMapper().map(
            details: makeTronUsdtDetails(capabilities: [.swap, .onramp, .offramp]),
            marketData: nil,
            balance: makeSnapshot(amount: 0),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.actionButtons, [.receive, .cashBuy])
    }

    @MainActor
    func test_mapper_withZeroTronUsdtBalance_disablesSendAndSell() {
        let screen = makeMapper().map(
            details: makeTronUsdtDetails(),
            marketData: nil,
            balance: makeSnapshot(amount: 0),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertNil(screen?.balance)
        XCTAssertEqual(screen?.isSendAvailable, false)
        XCTAssertEqual(screen?.actionBarState, .buy)
    }

    @MainActor
    func test_mapper_withSwapDisabled_hidesActionBar() {
        let screen = makeMapper(isSwapDisabled: true).map(
            details: makeTronUsdtDetails(),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.actionBarState, TradeAssetDetailsActionBarState.none)
    }

    @MainActor
    func test_mapper_withSwapDisabled_keepsCashButtons() {
        let screen = makeMapper(isSwapDisabled: true).map(
            details: makeTronUsdtDetails(capabilities: [.swap, .onramp, .offramp]),
            marketData: nil,
            balance: makeSnapshot(amount: 7_180_000),
            history: nil,
            multichainHistory: nil,
            tronFees: nil,
            isSecureMode: false
        ).screen

        XCTAssertEqual(screen?.actionBarState, TradeAssetDetailsActionBarState.none)
        XCTAssertEqual(screen?.actionButtons, [.send, .receive, .cashBuy, .cashSell])
    }
}

private extension TradeAssetDetailsActionBarStateTests {
    var tronUsdtAssetId: String {
        "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
    }

    @MainActor
    func makeMapper(
        multichainState: MultichainWalletState? = MultichainWalletState(
            walletId: "multichain",
            addresses: [
                MultichainWalletAddress(chain: .tron, address: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"),
            ]
        ),
        isSwapDisabled: Bool = false
    ) -> TradeAssetDetailsScreenMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = "\u{2009}"
        var signedConfiguration = configuration
        signedConfiguration.signPolicy = .always

        return TradeAssetDetailsScreenMapper(
            multichainState: multichainState,
            preview: TradeAssetDetailsViewModel.PreviewContext(assetID: tronUsdtAssetId),
            isSwapDisabled: isSwapDisabled,
            amountFormatter: AmountFormatter(configuration: configuration),
            signedAmountFormatter: AmountFormatter(configuration: signedConfiguration),
            currencyProvider: { .USD }
        )
    }

    func makeSnapshot(amount: BigUInt) -> TradeAssetDetailsBalanceSnapshot {
        TradeAssetDetailsBalanceSnapshot(
            symbol: TronSwift.USDT.symbol,
            imageURL: nil,
            amount: amount,
            fractionDigits: TronSwift.USDT.fractionDigits,
            convertedAmount: 7.18,
            tagText: TronSwift.USDT.tag,
            freshness: .actual
        )
    }

    func makeTronUsdtDetails(
        capabilities: Set<TradingAssetCapability> = [.swap]
    ) -> TradingAssetDetails {
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
                price: nil,
                changePercent: nil,
                changeAmount: nil,
                earnAPY: nil,
                verification: .whitelist
            ),
            capabilities: capabilities,
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
