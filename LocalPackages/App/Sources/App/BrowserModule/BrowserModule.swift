import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
public struct BrowserModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func createBrowserCoordinator() -> BrowserCoordinator {
        let navigationController = TKNavigationController()
        navigationController.configureDefaultAppearance()

        if !UIApplication.useSystemBarsAppearance {
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        return BrowserCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
        )
    }
}

extension BrowserModule {
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
