import KeeperCore
import Perps
import TKCoordinator
import TKCore
import UIKit

final class MultichainHistoryCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let didTapAddFunds: () -> Void
    private let onOpenTransaction: (URL, String?) -> Void
    private let onOpenLoyalty: () -> Void
    private let wallet: Wallet
    private let multichainState: MultichainWalletState
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let closeAction: (() -> Void)?
    private let pendingEventId: String?
    private lazy var perpsHistoryDetails = PerpsHistoryDetailsPresenter(
        marketsStore: keeperCoreMainAssembly.perpsAssembly.marketsStore,
        format: .live(appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore),
        onOpenLoyalty: onOpenLoyalty
    )

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        closeAction: (() -> Void)?,
        pendingEventId: String? = nil,
        didTapAddFunds: @escaping () -> Void,
        onOpenTransaction: @escaping (URL, String?) -> Void,
        onOpenLoyalty: @escaping () -> Void
    ) {
        self.wallet = wallet
        self.multichainState = multichainState
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.closeAction = closeAction
        self.pendingEventId = pendingEventId
        self.didTapAddFunds = didTapAddFunds
        self.onOpenTransaction = onOpenTransaction
        self.onOpenLoyalty = onOpenLoyalty
        super.init(router: router)
    }

    override func start() {
        start(animated: true)
    }
}

extension MultichainHistoryCoordinator: HistoryStarting {
    func start(animated: Bool) {
        openHistory(animated: animated)
    }
}

private extension MultichainHistoryCoordinator {
    func openHistory(animated: Bool) {
        let appSettingsStore = keeperCoreMainAssembly.storesAssembly.appSettingsStore
        let isPerpsEnabled = keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.perpsEnabled)
        let perpsScope = isPerpsEnabled && wallet.hasMultichainMnemonic
            ? keeperCoreMainAssembly.perpsAssembly.walletScope(for: wallet)
            : nil
        let viewModel = MultichainHistoryViewModelImplementation(
            multichainState: multichainState,
            hidesDustTransactions: appSettingsStore.getState().hidesDustTransactions,
            isPerpsEnabled: isPerpsEnabled,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            realtimeManager: keeperCoreMainAssembly.multichainAssembly.realtimeManager,
            reachabilityTracker: coreAssembly.reachabilityTracker,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            nftResolver: MultichainActivityNFTResolver(
                nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
                network: wallet.network
            ),
            encryptedComments: MultichainEncryptedComments(
                wallet: wallet,
                coordinator: self,
                presenter: router.rootViewController,
                keeperCoreAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            ),
            appSettingsStore: appSettingsStore,
            walletName: wallet.emojiLabel,
            onAddFunds: didTapAddFunds,
            pendingEventId: pendingEventId,
            walletScope: perpsScope,
            accountStore: perpsScope?.accountStore,
            format: .live(appSettingsStore: appSettingsStore),
            perpsHistoryEvents: keeperCoreMainAssembly.perpsAssembly.historyEvents(for: wallet)
        )
        viewModel.persistHistoryFilters(to: appSettingsStore)
        let viewController = MultichainHistoryViewController(
            viewModel: viewModel,
            onClose: closeAction,
            onOpenTransaction: onOpenTransaction,
            onSelectPerpsEvent: { [weak self] event in
                guard let self else { return }
                perpsHistoryDetails.present(event, from: router.rootViewController.topPresentedViewController())
            }
        )
        router.push(viewController: viewController, animated: animated)
    }
}
