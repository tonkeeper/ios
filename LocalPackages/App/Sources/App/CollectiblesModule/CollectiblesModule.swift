import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
struct CollectiblesModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createCollectiblesCoordinator(
        router: NavigationControllerRouter? = nil,
        configuresTabBarItem: Bool = true
    ) -> CollectiblesCoordinator {
        let navigationController: TKNavigationController
        if let router, let routerNavigationController = router.rootViewController as? TKNavigationController {
            navigationController = routerNavigationController
        } else {
            navigationController = TKNavigationController()

            navigationController.configureTransparentAppearance()
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        let collectiblesRouter = router ?? NavigationControllerRouter(rootViewController: navigationController)

        return CollectiblesCoordinator(
            router: collectiblesRouter,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            configuresTabBarItem: configuresTabBarItem
        )
    }
}

extension CollectiblesModule {
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
