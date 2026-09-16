import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
struct BrowserModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createBrowserCoordinator() -> BrowserCoordinator {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()

        navigationController.setNavigationBarHidden(true, animated: false)

        return BrowserCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            analyticsController: dependencies.analyticsController
        )
    }
}

extension BrowserModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let analyticsController: DappBrowserAnalyticsController

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            analyticsController: DappBrowserAnalyticsController
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.analyticsController = analyticsController
        }
    }
}
