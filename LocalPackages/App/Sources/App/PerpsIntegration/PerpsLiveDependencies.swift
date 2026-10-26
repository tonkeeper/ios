import KeeperCore
import Perps
import PerpsModels
import TKCore
import TKLogging
import UIKit

/// `PerpsAssembly` hands out live stores; the feature only ever names ports, so the
/// adapter is the one place the two vocabularies meet.
struct PerpsLiveDependencies: PerpsDependencies {
    let format = PerpsFormatting.live

    private let assembly: PerpsAssembly

    init(assembly: PerpsAssembly) {
        self.assembly = assembly
    }

    var marketsRepository: any PerpsMarketsSearching {
        assembly.marketsRepository
    }

    var marketsStore: any PerpsMarketsStoring {
        assembly.marketsStore
    }

    var chartService: any PerpsChartProviding {
        assembly.chartService
    }

    func makeMarketDetailsStore() -> any PerpsMarketDetailsStoring {
        assembly.makeMarketDetailsStore()
    }
}

enum PerpsWalletDependenciesFactory {
    static func make(
        walletScope: PerpsWalletScope,
        mainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> PerpsWalletDependencies {
        PerpsWalletDependencies(
            accountStore: walletScope.accountStore,
            tradingService: walletScope.tradingService,
            activateAccount: { parentCoordinator, parentRouter, onPasscodeEntered in
                if await walletScope.accountService.adoptRegisteredTradingKey(wallet: walletScope.wallet) {
                    return .activated
                }
                guard let passcode = await PasscodeInputCoordinator.getPasscode(
                    parentCoordinator: parentCoordinator,
                    parentRouter: parentRouter,
                    mnemonicAccess: mainAssembly.mnemonicAccess,
                    securityStore: mainAssembly.storesAssembly.securityStore,
                    analyticsProvider: nil,
                    reason: .perps
                ) else {
                    Log.perps.i("activation: passcode canceled")
                    return .canceled
                }
                onPasscodeEntered()
                switch await walletScope.accountService.activate(wallet: walletScope.wallet, passcode: passcode) {
                case .active:
                    return .activated
                case .noAccount, .failed:
                    return .failed
                }
            },
            signingPasscode: { parentCoordinator, parentRouter in
                await PasscodeInputCoordinator.getPasscode(
                    parentCoordinator: parentCoordinator,
                    parentRouter: parentRouter,
                    mnemonicAccess: mainAssembly.mnemonicAccess,
                    securityStore: mainAssembly.storesAssembly.securityStore,
                    analyticsProvider: nil,
                    reason: .perps
                )
            },
            recoverFunding: {
                let lifecycle = PerpsFundingLifecycle(
                    appState: coreAssembly.appStateTracker,
                    reachability: coreAssembly.reachabilityTracker
                )
                await walletScope.recoverFunding(while: lifecycle.states)
            },
            refreshFunding: {
                await walletScope.refreshFunding()
            },
            makeDeposit: {
                PerpsLiveDeposit(
                    walletScope: walletScope,
                    assetBalanceProvider: mainAssembly.multichainAssembly.multichainAssetBalanceProvider,
                    multichainService: mainAssembly.servicesAssembly.multichainService()
                )
            },
            makeWithdraw: {
                PerpsLiveWithdraw(
                    walletScope: walletScope,
                    assetBalanceProvider: mainAssembly.multichainAssembly.multichainAssetBalanceProvider,
                    multichainService: mainAssembly.servicesAssembly.multichainService()
                )
            },
            makeHistory: { marketId, focusedTransactions, withdrawalOperationId, focusedFundingOperationId, onSelectEvent, onOpenTransaction in
                makeHistory(
                    wallet: walletScope.wallet,
                    marketId: marketId,
                    focusedTransactions: focusedTransactions,
                    withdrawalOperationId: withdrawalOperationId,
                    focusedFundingOperationId: focusedFundingOperationId,
                    accountStore: walletScope.accountStore,
                    mainAssembly: mainAssembly,
                    onSelectEvent: onSelectEvent,
                    onOpenTransaction: onOpenTransaction
                )
            }
        )
    }

    @MainActor
    private static func makeHistory(
        wallet: Wallet,
        marketId: Int64?,
        focusedTransactions: Set<String>,
        withdrawalOperationId: String?,
        focusedFundingOperationId: String?,
        accountStore: any PerpsAccountStoring,
        mainAssembly: KeeperCore.MainAssembly,
        onSelectEvent: @escaping (PerpsHistoryEvent) -> Void,
        onOpenTransaction: @escaping (URL, String?) -> Void
    ) -> UIViewController? {
        guard let multichainState = wallet.multichainWalletState else { return nil }
        let viewModel = PerpsHistoryViewModel(
            multichainState: multichainState,
            marketId: marketId,
            focusedTransactions: focusedTransactions,
            withdrawalOperationId: withdrawalOperationId,
            focusedFundingOperationId: focusedFundingOperationId,
            accountStore: accountStore,
            multichainService: mainAssembly.servicesAssembly.multichainService(),
            amountFormatter: mainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: mainAssembly.formattersAssembly.dateFormatter,
            nftResolver: MultichainActivityNFTResolver(
                nftService: mainAssembly.servicesAssembly.nftService(),
                network: wallet.network
            )
        )
        return PerpsHistoryViewController(
            viewModel: viewModel,
            onSelectEvent: onSelectEvent,
            onOpenTransaction: onOpenTransaction
        )
    }
}
