import KeeperCore
import Perps
import TKCoordinator
import TKCore
import UIKit

final class MultichainHistoryCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let didTapAddFunds: () -> Void
    private let onOpenTransaction: (URL, String?) -> Void
    private let wallet: Wallet
    private let multichainState: MultichainWalletState
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let presentationStyle: HistoryPresentationStyle
    private let pendingEventId: String?
    private lazy var perpsHistoryDetails = PerpsHistoryDetailsPresenter(
        marketsStore: keeperCoreMainAssembly.perpsAssembly.marketsStore,
        format: .live
    )

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        presentationStyle: HistoryPresentationStyle,
        pendingEventId: String? = nil,
        didTapAddFunds: @escaping () -> Void,
        onOpenTransaction: @escaping (URL, String?) -> Void
    ) {
        self.wallet = wallet
        self.multichainState = multichainState
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.presentationStyle = presentationStyle
        self.pendingEventId = pendingEventId
        self.didTapAddFunds = didTapAddFunds
        self.onOpenTransaction = onOpenTransaction
        super.init(router: router)
    }

    override func start() {
        openHistory()
    }
}

private extension MultichainHistoryCoordinator {
    func openHistory() {
        let appSettingsStore = keeperCoreMainAssembly.storesAssembly.appSettingsStore
        let viewModel = MultichainHistoryViewModelImplementation(
            multichainState: multichainState,
            hidesDustTransactions: appSettingsStore.getState().hidesDustTransactions,
            isPerpsEnabled: keeperCoreMainAssembly.configurationAssembly.configuration
                .featureEnabled(.perpsEnabled),
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            realtimeManager: keeperCoreMainAssembly.multichainAssembly.realtimeManager,
            reachabilityTracker: coreAssembly.reachabilityTracker,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            nftResolver: MultichainActivityNFTResolver(
                nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
                network: wallet.network
            ),
            onAddFunds: didTapAddFunds,
            pendingEventId: pendingEventId
        )
        viewModel.persistHistoryFilters(to: appSettingsStore)
        let viewController = MultichainHistoryViewController(
            viewModel: viewModel,
            onClose: presentationStyle.closeAction,
            onOpenTransaction: onOpenTransaction,
            onSelectPerpsEvent: { [weak self] event in
                guard let self else { return }
                perpsHistoryDetails.present(event, from: router.rootViewController.topPresentedViewController())
            }
        )
        router.push(viewController: viewController, animated: true)
    }
}
