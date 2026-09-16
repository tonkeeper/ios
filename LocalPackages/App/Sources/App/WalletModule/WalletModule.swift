import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

@MainActor
struct WalletModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createWalletCoordinator() -> WalletCoordinator {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()

        return WalletCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
        )
    }

    func createMultichainWalletCoordinator() -> MultichainWalletCoordinator {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()

        return MultichainWalletCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
        )
    }
}

extension WalletModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
        }
    }
}
