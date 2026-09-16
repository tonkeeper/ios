import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKUIKit
import UIKit

@MainActor
struct TradeModule {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createTradeCoordinator(
        output: CoordinatorOutput
    ) -> TradeCoordinator {
        Log.trade.i("init coordinator")
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        navigationController.setNavigationBarHidden(true, animated: false)

        return TradeCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            tradeAssetDetailsHotWindow: dependencies.tradeAssetDetailsHotWindow,
            jettonService: dependencies.keeperCoreMainAssembly.servicesAssembly.jettonService(),
            shelvesService: dependencies.keeperCoreMainAssembly.servicesAssembly.tradingShelvesService(),
            favoriteAssetsService: dependencies.keeperCoreMainAssembly.servicesAssembly.tradingFavoriteAssetsService(),
            assetsListService: dependencies.keeperCoreMainAssembly.servicesAssembly.assetsListService(),
            assetDetailsService: dependencies.keeperCoreMainAssembly.servicesAssembly.assetDetailsService(),
            balanceService: dependencies.keeperCoreMainAssembly.servicesAssembly.balanceService(),
            ratesService: dependencies.keeperCoreMainAssembly.servicesAssembly.ratesService(),
            currencyStore: dependencies.keeperCoreMainAssembly.storesAssembly.currencyStore,
            amountFormatter: dependencies.keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            signedAmountFormatter: dependencies.keeperCoreMainAssembly.formattersAssembly.signedAmountFormatter,
            chartViewStateProvider: { wallet, assetId in
                dependencies.keeperCoreMainAssembly.chartV2Controller(
                    assetId: assetId,
                    wallet: wallet
                ).map { chartController in
                    ChartAssembly
                        .viewState(
                            chartController: chartController,
                            coreAssembly: dependencies.coreAssembly,
                            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
                        )
                }
            },
            output: output
        )
    }
}

extension TradeModule {
    enum SwapContext {
        case ton(
            from: TonToken,
            to: TonToken,
            fromCategory: TradingAssetCategory? = nil,
            toCategory: TradingAssetCategory? = nil
        )
        case tron
        case multichain(MultichainSwapInitialAssetSelection)
    }

    struct CoordinatorOutput {
        var onSwap: (SwapContext, Wallet, UINavigationController?) -> Void
        var onSend: (Wallet, SendV3Item, UINavigationController?) -> Void
        var onSendMultichain: (Wallet, MultichainWalletState, MultichainSendInput, UINavigationController?) -> Void
        var onReceive: (Token, Wallet, UINavigationController?) -> Void
        var onReceiveMultichain: (Wallet, ReceiveAddressPreview, UINavigationController?) -> Void
        var onSellToCard: (Wallet, TradingAssetInfo, MultichainAsset?, UINavigationController?) -> Void
        var onCashBuy: (Wallet, TradingAssetInfo, UINavigationController?) -> Void
        var onTronUsdtFees: (Wallet, TronUsdtFeesSnapshot, TradeAssetDetailsTronFeesTrigger) -> Void
        var onOpenStaking: (Wallet) -> Void
        var onOpenPerps: ((UINavigationController?) -> Void)?
        var onOpenPerpsMarket: ((Int64, UINavigationController?) -> Void)?
        var onOpenHistoryEvent: (TradeAssetHistorySelection, UINavigationController?) -> Void
        var tokenDetailsConfiguratorProvider: (Wallet, Token) -> TokenDetailsConfigurator?
        var onOpenUnverifiedTokenInfoPopup: (UINavigationController?) -> Void
        var onOpenVerifiedTokenInfoPopup: (UINavigationController?) -> Void
        var onOpenUrl: (URL, UINavigationController?) -> Void
    }
}

extension TradeModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let tradeAssetDetailsHotWindow: TradeAssetDetailsHotWindow

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            tradeAssetDetailsHotWindow: TradeAssetDetailsHotWindow
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.tradeAssetDetailsHotWindow = tradeAssetDetailsHotWindow
        }
    }
}
