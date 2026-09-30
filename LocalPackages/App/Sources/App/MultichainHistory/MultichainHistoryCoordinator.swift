import KeeperCore
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

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        presentationStyle: HistoryPresentationStyle,
        didTapAddFunds: @escaping () -> Void,
        onOpenTransaction: @escaping (URL, String?) -> Void
    ) {
        self.wallet = wallet
        self.multichainState = multichainState
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.presentationStyle = presentationStyle
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
            onAddFunds: didTapAddFunds
        )
        viewModel.persistHistoryFilters(to: appSettingsStore)
        let viewController = MultichainHistoryViewController(
            viewModel: viewModel,
            onClose: presentationStyle.closeAction,
            onOpenTransaction: onOpenTransaction
        )
        router.push(viewController: viewController, animated: true)
    }
}
