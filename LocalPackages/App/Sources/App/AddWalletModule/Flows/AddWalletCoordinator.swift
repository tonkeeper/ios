import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKUIKit
import UIKit

final class AddWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didCancel: (() -> Void)?
    var didAddWallets: (() -> Void)?

    private var pairSignerCoordinator: PairSignerCoordinator?

    private let options: [AddWalletOption]
    private let configurationAssembly: ConfigurationAssembly
    private let multichainSupportedChains: [MultichainChain]
    private let walletAddController: WalletAddController
    private let analyticsProvider: AnalyticsProvider
    private let analyticsContext: WalletFlowAnalyticsContext
    private let createWalletCoordinatorProvider: (ViewControllerRouter, CreateWalletCoordinator.Mode) -> CreateWalletCoordinator
    private let importWalletCoordinatorProvider: (NavigationControllerRouter, _ network: Network) -> ImportWalletCoordinator
    private let importWatchOnlyWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator
    private let pairSignerCoordinatorProvider: (NavigationControllerRouter) -> PairSignerCoordinator
    private let pairLedgerCoordinatorProvider: (ViewControllerRouter) -> PairLedgerCoordinator
    private let pairKeystoneCoordinatorProvider: (NavigationControllerRouter) -> PairKeystoneCoordinator

    init(
        router: ViewControllerRouter,
        options: [AddWalletOption],
        configurationAssembly: ConfigurationAssembly,
        multichainSupportedChains: [MultichainChain],
        walletAddController: WalletAddController,
        analyticsProvider: AnalyticsProvider,
        analyticsContext: WalletFlowAnalyticsContext,
        createWalletCoordinatorProvider: @escaping (ViewControllerRouter, CreateWalletCoordinator.Mode) -> CreateWalletCoordinator,
        importWalletCoordinatorProvider: @escaping (NavigationControllerRouter, _ network: Network) -> ImportWalletCoordinator,
        importWatchOnlyWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator,
        pairSignerCoordinatorProvider: @escaping (NavigationControllerRouter) -> PairSignerCoordinator,
        pairLedgerCoordinatorProvider: @escaping (ViewControllerRouter) -> PairLedgerCoordinator,
        pairKeystoneCoordinatorProvider: @escaping (NavigationControllerRouter) -> PairKeystoneCoordinator
    ) {
        self.configurationAssembly = configurationAssembly
        self.multichainSupportedChains = multichainSupportedChains
        self.walletAddController = walletAddController
        self.analyticsProvider = analyticsProvider
        self.analyticsContext = analyticsContext
        self.options = options.unique
        self.createWalletCoordinatorProvider = createWalletCoordinatorProvider
        self.importWalletCoordinatorProvider = importWalletCoordinatorProvider
        self.importWatchOnlyWalletCoordinatorProvider = importWatchOnlyWalletCoordinatorProvider
        self.pairSignerCoordinatorProvider = pairSignerCoordinatorProvider
        self.pairLedgerCoordinatorProvider = pairLedgerCoordinatorProvider
        self.pairKeystoneCoordinatorProvider = pairKeystoneCoordinatorProvider
        super.init(router: router)
    }

    override func start() {
        openAddWalletOptionPicker()
    }

    override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        guard let tonkeeperDeeplink = deeplink as? Deeplink else { return false }

        switch tonkeeperDeeplink {
        case .externalSign:
            guard let pairSignerCoordinator else { return false }
            return pairSignerCoordinator.handleDeeplink(deeplink: tonkeeperDeeplink)
        default:
            return false
        }
    }
}

private extension AddWalletCoordinator {
    func openAddWalletOptionPicker() {
        analyticsProvider.log(AddWalletMenuView(from: analyticsContext.from))
        let module = AddWalletOptionPickerAssembly.module(
            options: options,
            multichainImportChains: multichainSupportedChains
        )

        module.output.didSelectOption = { [weak self, weak viewController = module.view] option in
            viewController?.dismissFromCoordinator(animated: true) {
                self?.handleSelectedOption(option)
            }
        }

        module.output.didRequestClose = { [weak self, weak viewController = module.view] in
            guard let viewController else {
                self?.didCancel?()
                return
            }

            viewController.dismissFromCoordinator(animated: true) {
                self?.didCancel?()
            }
        }

        module.view.didDismissInteractively = { [weak self] in
            self?.didCancel?()
        }

        router.rootViewController.topPresentedViewController().present(module.view, animated: true)
    }

    func handleSelectedOption(_ option: AddWalletOption) {
        logImportStarted(for: option)
        switch option {
        case .createRegular:
            openCreateRegularWallet(router: router)
        case .createMultichain:
            openCreateMultichainWallet(router: router)
        case .importRegular:
            openAddWallet(network: .mainnet)
        case .importWatchOnly:
            openAddWatchOnlyWallet()
        case .signer:
            openPairSigner()
        case .keystone:
            openPairKeystone()
        case .ledger:
            openPairLedger()
        }
    }

    func logImportStarted(for option: AddWalletOption) {
        let walletSource: WalletSource
        let walletMode: WalletMode

        switch option {
        case .createRegular, .createMultichain, .importRegular:
            return
        case .importWatchOnly:
            walletSource = .watchonly
            walletMode = .single
        case .signer:
            walletSource = .signer
            walletMode = .single
        case .keystone:
            walletSource = .keystone
            walletMode = .single
        case .ledger:
            walletSource = .ledger
            walletMode = .single
        }

        analyticsProvider.logWalletImportStarted(
            walletMode: walletMode,
            walletSource: walletSource,
            from: analyticsContext.from
        )
    }

    func openCreateMultichainWallet(router: ViewControllerRouter) {
        openCreateWallet(router: router, mode: .multichain)
    }

    func openCreateRegularWallet(router: ViewControllerRouter) {
        openCreateWallet(router: router, mode: .regular)
    }

    func openCreateWallet(
        router: ViewControllerRouter,
        mode: CreateWalletCoordinator.Mode
    ) {
        let coordinator = createWalletCoordinatorProvider(
            router,
            mode
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            self?.didCancel?()
        }

        coordinator.didRequestBack = { [weak self, weak coordinator] in
            self?.router.dismiss(animated: true) { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
                self?.openAddWalletOptionPicker()
            }
        }

        coordinator.didCreateWallet = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            self?.didAddWallets?()
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openAddWatchOnlyWallet() {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        let router = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = importWatchOnlyWalletCoordinatorProvider(
            router
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            router.dismiss(animated: true) {
                self?.didCancel?()
            }
            guard let coordinator = coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didImportWallet = { [weak self, weak coordinator] in
            guard let coordinator = coordinator else { return }
            self?.removeChild(coordinator)
            router.dismiss(animated: true) {
                self?.didAddWallets?()
            }
        }

        addChild(coordinator)
        coordinator.start()

        self.router.present(navigationController, onDismiss: { [weak self] in
            self?.didCancel?()
        })
    }

    func openAddWallet(network: Network) {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        let router = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = importWalletCoordinatorProvider(
            router, network
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true, completion: {
                self?.didCancel?()
            })
        }

        coordinator.didImportWallets = { [weak self, weak coordinator] in
            guard let coordinator = coordinator else { return }
            self?.removeChild(coordinator)
            router.dismiss(animated: true) {
                self?.didAddWallets?()
            }
        }

        addChild(coordinator)
        coordinator.start()

        self.router.present(navigationController, onDismiss: { [weak self] in
            self?.didCancel?()
        })
    }

    func openPairKeystone() {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        let router = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = pairKeystoneCoordinatorProvider(
            router
        )

        addChild(coordinator)
        coordinator.start()

        coordinator.didCancel = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true, completion: {
                self?.didCancel?()
            })
        }

        coordinator.didPaired = { [weak self, weak coordinator] in
            router.dismiss(animated: true) {
                self?.didAddWallets?()
            }
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        self.router.present(navigationController, onDismiss: { [weak self] in
            self?.didCancel?()
        })
    }

    func openPairSigner() {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        let router = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = pairSignerCoordinatorProvider(
            router
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            router.dismiss(animated: true) {
                self?.didCancel?()
            }
            self?.pairSignerCoordinator = nil
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didPaired = { [weak self, weak coordinator] in
            router.dismiss(animated: true) {
                self?.didAddWallets?()
            }
            self?.pairSignerCoordinator = nil
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        self.pairSignerCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()

        self.router.present(navigationController, onDismiss: { [weak self] in
            self?.didCancel?()
        })
    }

    func openPairLedger() {
        let coordinator = pairLedgerCoordinatorProvider(router)

        coordinator.didCancel = { [weak self, weak coordinator] in
            self?.didCancel?()
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didPaired = { [weak self, weak coordinator] in
            self?.didAddWallets?()
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        addChild(coordinator)
        coordinator.start()
    }
}
