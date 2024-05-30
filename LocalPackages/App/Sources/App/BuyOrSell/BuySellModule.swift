import TKCoordinator
import TKCore
import KeeperCore
import BigInt

struct BuySellModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    public func createBuySellCoordinator(router: NavigationControllerRouter, wallet: Wallet, token: Token, amount: BigUInt) -> BuySellCoordinator {
        let buyInputController = dependencies.keeperCoreMainAssembly.buyInputController(wallet: wallet)
        let sellInputController = dependencies.keeperCoreMainAssembly.sellInputController(wallet: wallet)
        
        let operatorsController = dependencies.keeperCoreMainAssembly.operatorsController(
            wallet: wallet,
            isMarketRegionPickerAvailable: dependencies.coreAssembly.featureFlagsProvider.isMarketRegionPickerAvailable
        )
        
        let settingsController = dependencies.keeperCoreMainAssembly.settingsController
        
        let confirmationInputController = dependencies.keeperCoreMainAssembly.confirmationInputController(wallet: wallet)
        
        let coordinator = BuySellCoordinator(
            router: router,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            buyInputController: buyInputController,
            sellInputController: sellInputController,
            operatorsController: operatorsController,
            settingsController: settingsController,
            confirmationInputController: confirmationInputController
        )
        return coordinator
    }
}

extension BuySellModule {
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
