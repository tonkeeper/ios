import TKCoordinator
import TKCore
import KeeperCore
import BigInt

struct StakingModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    public func createStakingCoordinator(router: NavigationControllerRouter, wallet: Wallet) -> StakingCoordinator {
        let stakingAmountController = dependencies.keeperCoreMainAssembly.stakingAmountController(
            wallet: wallet
        )
        
        let stakingOptionsController = dependencies.keeperCoreMainAssembly.stakingOptionsController(
            wallet: wallet
        )
        
        let coordinator = StakingCoordinator(
            router: router,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            stakingAmountController: stakingAmountController,
            stakingOptionsController: stakingOptionsController,
            wallet: wallet
        )
        return coordinator
    }
}

extension StakingModule {
    struct Dependencies {
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let coreAssembly: TKCore.CoreAssembly
        
        init(keeperCoreMainAssembly: KeeperCore.MainAssembly,
             coreAssembly: TKCore.CoreAssembly) {
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.coreAssembly = coreAssembly
        }
    }
}
