import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
public struct CollectiblesModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func createCollectiblesCoordinator(parentRouter: TabBarControllerRouter?) -> CollectiblesCoordinator {
        let navigationController = TKNavigationController()

        if !UIApplication.useSystemBarsAppearance {
            navigationController.configureTransparentAppearance()
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        return CollectiblesCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            parentRouter: parentRouter,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
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
