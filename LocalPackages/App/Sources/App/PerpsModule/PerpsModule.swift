import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
struct PerpsModule {
    func createPerpsCoordinator(
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        walletScope: PerpsWalletScope,
        analyticsProvider: AnalyticsProvider? = nil
    ) -> PerpsCoordinator {
        PerpsCoordinator(
            router: router,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            walletScope: walletScope,
            analyticsProvider: analyticsProvider
        )
    }
}
