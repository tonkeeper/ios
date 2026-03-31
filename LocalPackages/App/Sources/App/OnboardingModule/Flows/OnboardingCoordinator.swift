import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

public final class OnboardingCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private weak var addWalletCoordinator: AddWalletCoordinator?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly
    private let configurationAssembly: ConfigurationAssembly

    public var didFinishOnboarding: (() -> Void)?

    init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreOnboardingAssembly = keeperCoreOnboardingAssembly
        self.configurationAssembly = configurationAssembly
        super.init(router: router)
    }

    override public func start(deeplink: CoordinatorDeeplink? = nil) {
        openOnboardingStart()
        _ = handleDeeplink(deeplink: deeplink)
    }

    override public func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        guard let coreDeeplink = deeplink as? KeeperCore.Deeplink else { return false }
        return handleCoreDeeplink(coreDeeplink)
    }
}

private extension OnboardingCoordinator {
    func openOnboardingStart() {
        let module = OnboardingRootAssembly.module()

        module.output.didTapCreateButton = { [weak self] in
            self?.openCreate()
        }

        module.output.didTapImportButton = { [weak self] in
            guard let self else { return }
            self.openAddWallet(router: ViewControllerRouter(rootViewController: self.router.rootViewController))
        }

        router.push(viewController: module.view, animated: false)
    }

    func openCreate() {
        let coordinator = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreOnboardingAssembly.walletsUpdateAssembly,
                storesAssembly: keeperCoreOnboardingAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreOnboardingAssembly.scannerAssembly(),
                configurationAssembly: configurationAssembly
            )
        ).createCreateWalletCoordinator(
            router: ViewControllerRouter(rootViewController: router.rootViewController)
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didCreateWallet = { [weak self, weak coordinator] in
            self?.didFinishOnboarding?()
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openAddWallet(router: ViewControllerRouter) {
        let module = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreOnboardingAssembly.walletsUpdateAssembly,
                storesAssembly: keeperCoreOnboardingAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreOnboardingAssembly.scannerAssembly(),
                configurationAssembly: configurationAssembly
            )
        )

        let coordinator = module.createAddWalletCoordinator(
            options: [
                .importRegular,
                .signer,
                .keystone,
                .ledger,
                .importWatchOnly,
                .importTestnet,
                .importTetra,
            ],
            router: router
        )
        coordinator.didAddWallets = { [weak self, weak coordinator] in
            self?.didFinishOnboarding?()
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }
        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        addWalletCoordinator = coordinator

        addChild(coordinator)
        coordinator.start()
    }

    func handleCoreDeeplink(_ deeplink: KeeperCore.Deeplink) -> Bool {
        switch deeplink {
        case let .externalSign(externalSign):
            if let addWalletCoordinator, addWalletCoordinator.handleDeeplink(deeplink: deeplink) {
                return true
            }
            router.dismiss(animated: true) { [weak self] in
                self?.handleSignerDeeplink(externalSign)
            }
            return true
        default:
            return false
        }
    }

    func handleSignerDeeplink(_ deeplink: ExternalSignDeeplink) {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        switch deeplink {
        case let .link(publicKey, name):
            let coordinator = AddWalletModule(
                dependencies: AddWalletModule.Dependencies(
                    walletsUpdateAssembly: keeperCoreOnboardingAssembly.walletsUpdateAssembly,
                    storesAssembly: keeperCoreOnboardingAssembly.storesAssembly,
                    coreAssembly: coreAssembly,
                    scannerAssembly: keeperCoreOnboardingAssembly.scannerAssembly(),
                    configurationAssembly: configurationAssembly
                )
            ).createPairSignerDeeplinkCoordinator(
                publicKey: publicKey,
                name: name,
                router: NavigationControllerRouter(
                    rootViewController: navigationController
                )
            )

            coordinator.didPrepareToPresent = { [weak self, weak navigationController] in
                guard let navigationController else { return }
                self?.router.present(navigationController)
            }

            coordinator.didPaired = { [weak self, weak coordinator, weak navigationController] in
                self?.didFinishOnboarding?()
                navigationController?.dismiss(animated: true)
                self?.removeChild(coordinator)
            }

            coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
                navigationController?.dismiss(animated: true)
                self?.removeChild(coordinator)
            }

            addChild(coordinator)
            coordinator.start()
        }
    }
}
