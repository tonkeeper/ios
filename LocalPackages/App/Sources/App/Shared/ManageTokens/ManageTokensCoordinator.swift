import KeeperCore
import TKCoordinator
import TKUIKit
import UIKit

@MainActor
final class ManageTokensCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didSaveVisibilityChanges: ((TokenManagementVisibilityUpdate) -> Void)?

    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let balanceLoader: BalanceLoader
    private let visibilityChangesController: VisibilityChangesController

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        balanceLoader: BalanceLoader,
        visibilityChangesController: VisibilityChangesController
    ) {
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.balanceLoader = balanceLoader
        self.visibilityChangesController = visibilityChangesController
        super.init(router: router)
    }

    override func start() {
        switch wallet.multichain {
        case let .multichain(state):
            openMultichainManageTokens(multichainState: state)
        case .unavailable, nil:
            openLegacyManageTokens()
        }
    }
}

private extension ManageTokensCoordinator {
    func openLegacyManageTokens() {
        let updateQueue = DispatchQueue(label: "ManageTokensQueue")

        let module = ManageTokensAssembly.module(
            model: ManageTokensModel(
                wallet: wallet,
                tokenManagementStore: keeperCoreMainAssembly.storesAssembly.tokenManagementStore,
                convertedBalanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
                stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
                updateQueue: updateQueue
            ),
            mapper: ManageTokensListMapper(amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter),
            updateQueue: updateQueue,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )

        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.setNavigationBarHidden(true, animated: false)

        router.present(navigationController, onDismiss: { [weak self] in
            guard let self else { return }
            didFinish?(self)
        })
    }

    func openMultichainManageTokens(multichainState: MultichainWalletState) {
        let displayCurrency = keeperCoreMainAssembly.storesAssembly.currencyStore.getState()
        let service = MultichainPortfolioTokenManagementService(
            multichainState: multichainState,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            visibilityChangesController: visibilityChangesController,
            displayCurrency: displayCurrency,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        let availableChains = MultichainChain.allCases.map { chain in
            let configuration = chain.addressConfiguration
            return TokenManagementChain(
                id: chain.rawValue,
                title: configuration.title,
                badgeTitle: chain.badgeTitle,
                icon: configuration.icon
            )
        }

        let coordinator = TokenManagementModule().makeCoordinator(
            router: router,
            availableChains: availableChains,
            service: service,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore
        )

        addChild(coordinator)
        let eventStream = coordinator.startHandlingEvents()
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in eventStream {
                if case let .save(update) = event {
                    didSaveVisibilityChanges?(update)
                    await balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
                }
            }
            removeChild(coordinator)
            didFinish?(self)
        }
    }
}
