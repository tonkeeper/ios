import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

@MainActor
struct SettingsModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createSettingsCoordinator(router: NavigationControllerRouter, wallet: Wallet) -> SettingsCoordinator {
        return SettingsCoordinator(
            wallet: wallet,
            inAppReviewService: dependencies.inAppReviewService,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            depositPendingTracker: dependencies.depositPendingTracker
        )
    }
}

extension SettingsModule {
    struct Dependencies {
        let inAppReviewService: InAppReviewService
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let coreAssembly: TKCore.CoreAssembly
        let depositPendingTracker: DepositPendingTracker

        init(
            inAppReviewService: InAppReviewService,
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            coreAssembly: TKCore.CoreAssembly,
            depositPendingTracker: DepositPendingTracker
        ) {
            self.inAppReviewService = inAppReviewService
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.coreAssembly = coreAssembly
            self.depositPendingTracker = depositPendingTracker
        }
    }
}
