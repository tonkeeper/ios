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
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router
        )
    }
}

extension SettingsModule {
    struct Dependencies {
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let coreAssembly: TKCore.CoreAssembly

        init(
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            coreAssembly: TKCore.CoreAssembly
        ) {
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.coreAssembly = coreAssembly
        }
    }
}
