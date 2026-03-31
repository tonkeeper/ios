import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

@MainActor
struct NativeSwapModule {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func swapCoordinator(
        wallet: Wallet,
        fromToken: String? = nil,
        toToken: String? = nil,
        router: NavigationControllerRouter
    ) -> NativeSwapCoordinator {
        NativeSwapCoordinator(
            wallet: wallet,
            fromToken: fromToken,
            toToken: toToken,
            router: router,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
        )
    }
}

extension NativeSwapModule {
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
