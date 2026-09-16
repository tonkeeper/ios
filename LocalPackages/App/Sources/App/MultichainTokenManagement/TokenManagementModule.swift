import KeeperCore
import TKCoordinator
import UIKit

@MainActor
struct TokenManagementModule {
    func makeCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        availableChains: [TokenManagementChain],
        service: TokenManagementService,
        appSettingsStore: AppSettingsStore
    ) -> TokenManagementCoordinator {
        TokenManagementCoordinatorImplementation(
            router: router,
            availableChains: availableChains,
            service: service,
            appSettingsStore: appSettingsStore
        )
    }
}
