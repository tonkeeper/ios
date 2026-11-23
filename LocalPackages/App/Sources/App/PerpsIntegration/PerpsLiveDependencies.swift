import KeeperCore
import Perps
import PerpsModels
import TKCore
import TKLogging
import UIKit

/// `PerpsAssembly` hands out live stores; the feature only ever names ports, so the
/// adapter is the one place the two vocabularies meet.
struct PerpsLiveDependencies: PerpsDependencies {
    let format: PerpsFormatting

    private let assembly: PerpsAssembly

    init(assembly: PerpsAssembly, appSettingsStore: AppSettingsStore) {
        self.assembly = assembly
        format = .live(appSettingsStore: appSettingsStore)
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

    var access: PerpsAccess {
        assembly.access
    }

    func reloadAccess() async -> PerpsAccess {
        await assembly.reloadAccess()
    }

    func observeAccess<Observer: AnyObject>(_ observer: Observer, onChange: @escaping @Sendable (Observer) -> Void) {
        assembly.observeAccess(observer, onChange: onChange)
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
                if await walletScope.adoptRegisteredTradingKey() {
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
                switch await walletScope.activate(passcode: passcode) {
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
            makeDeposit: { sheetPresenter in
                PerpsLiveDeposit(
                    walletScope: walletScope,
                    assetBalanceProvider: mainAssembly.multichainAssembly.multichainAssetBalanceProvider,
                    multichainService: mainAssembly.servicesAssembly.multichainService(),
                    assetDetailsService: mainAssembly.servicesAssembly.assetDetailsService(),
                    amountFormatter: mainAssembly.formattersAssembly.amountFormatter,
                    feeRefill: PerpsFeeRefill(wallet: walletScope.wallet, coreAssembly: coreAssembly, keeperCoreMainAssembly: mainAssembly),
                    batteryService: mainAssembly.batteryAssembly.batteryService(),
                    isBatteryFeeEnabled: coreAssembly.featureFlags[.perpsBatteryFeeEnabled],
                    sheetPresenter: sheetPresenter
                )
            },
            makeWithdraw: {
                PerpsLiveWithdraw(
                    walletScope: walletScope,
                    assetBalanceProvider: mainAssembly.multichainAssembly.multichainAssetBalanceProvider,
                    multichainService: mainAssembly.servicesAssembly.multichainService(),
                    assetDetailsService: mainAssembly.servicesAssembly.assetDetailsService()
                )
            },
            makeHistory: { marketId, focusedTransactions, focusedFundingOperationId, onSelectEvent, onOpenTransaction in
                makeHistory(
                    wallet: walletScope.wallet,
                    marketId: marketId,
                    focusedTransactions: focusedTransactions,
                    focusedFundingOperationId: focusedFundingOperationId,
                    accountStore: walletScope.accountStore,
                    mainAssembly: mainAssembly,
                    onSelectEvent: onSelectEvent,
                    onOpenTransaction: onOpenTransaction
                )
            },
            loyalty: makeLoyalty(
                store: mainAssembly.loyaltyStore,
                walletsStore: mainAssembly.storesAssembly.walletsStore,
                wallet: walletScope.wallet
            ),
            hasOtherWallets: { [walletsStore = mainAssembly.storesAssembly.walletsStore, wallet = walletScope.wallet] in
                walletsStore.wallets.contains { $0.hasMultichainMnemonic && $0.id != wallet.id }
            },
            track: { [analyticsProvider = coreAssembly.analyticsProvider] in analyticsProvider.log($0, wallet: walletScope.wallet) }
        )
    }

    private static func makeLoyalty(store: LoyaltyStore, walletsStore: WalletsStore, wallet: Wallet) -> PerpsLoyalty {
        let current = { walletsStore.getWallet(id: wallet.id) ?? wallet }
        return PerpsLoyalty(
            showsBanner: { store.entry(for: current()).showsBanner },
            reload: { await store.reload(wallet: current()) },
            hideBanner: { store.hideBanner(wallet: current()) },
            reward: { try await store.perpsReward(wallet: current(), volumeUsd: $0) }
        )
    }

    @MainActor
    private static func makeHistory(
        wallet: Wallet,
        marketId: Int64?,
        focusedTransactions: Set<String>,
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
            focusedFundingOperationId: focusedFundingOperationId,
            accountStore: accountStore,
            format: .live(appSettingsStore: mainAssembly.storesAssembly.appSettingsStore),
            walletName: wallet.emojiLabel,
            multichainService: mainAssembly.servicesAssembly.multichainService(),
            historyEvents: mainAssembly.perpsAssembly.historyEvents(for: wallet),
            realtimeManager: mainAssembly.multichainAssembly.realtimeManager,
            amountFormatter: mainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: mainAssembly.formattersAssembly.dateFormatter,
            nftResolver: MultichainActivityNFTResolver(
                nftService: mainAssembly.servicesAssembly.nftService(),
                network: wallet.network
            ),
            appSettingsStore: mainAssembly.storesAssembly.appSettingsStore
        )
        return PerpsHistoryViewController(
            viewModel: viewModel,
            onSelectEvent: onSelectEvent,
            onOpenTransaction: onOpenTransaction
        )
    }
}
