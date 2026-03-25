import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

@MainActor
struct MainModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createMainCoordinator() -> MainCoordinator {
        let tabBarController = TKTabBarController()
        tabBarController.configureAppearance()

        return MainCoordinator(
            router: TabBarControllerRouter(rootViewController: tabBarController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            appStateTracker: dependencies.coreAssembly.appStateTracker,
            reachabilityTracker: dependencies.coreAssembly.reachabilityTracker,
            recipientResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.recipientResolver(),
            insufficientFundsValidator: dependencies.keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator()
        )
    }
}

extension MainModule {
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
