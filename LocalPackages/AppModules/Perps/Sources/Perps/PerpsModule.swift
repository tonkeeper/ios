import TKCoordinator
import UIKit

@MainActor
public struct PerpsModule {
    public init() {}

    public func createPerpsCoordinator(
        router: NavigationControllerRouter,
        perpsAssembly: any PerpsDependencies,
        walletDependencies: PerpsWalletDependencies
    ) -> PerpsCoordinator {
        PerpsCoordinator(
            router: router,
            perpsAssembly: perpsAssembly,
            walletDependencies: walletDependencies
        )
    }
}
