import TKCoordinator
import TKCore
import KeeperCore
import BigInt

struct SwapModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    public func createSwapCoordinator(router: NavigationControllerRouter, wallet: Wallet, token: Token, amount: BigUInt) -> SwapCoordinator {
        let swapSearchTokenController = dependencies.keeperCoreMainAssembly.swapSearchTokenController(
            wallet: wallet
        )
        
        let swapInfoController = dependencies.keeperCoreMainAssembly.swapInfoController(
            token: token,
            tokenAmount: amount,
            wallet: wallet
        )
        
        let coordinator = SwapCoordinator(
            router: router,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            swapSearchTokenController: swapSearchTokenController,
            swapInfoController: swapInfoController
        )
        return coordinator
    }
}

extension SwapModule {
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
