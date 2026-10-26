import KeeperCore
import TKCoordinator
import TKCore
import UIKit

@MainActor
struct PickMultichainAddressModule {
    func makeCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        addresses: [MultichainWalletAddress],
        newChainBadgeService: NewChainBadgeService
    ) -> PickMultichainAddressCoordinator {
        PickMultichainAddressCoordinatorImplementation(
            router: router,
            addresses: addresses,
            newChainBadgeService: newChainBadgeService
        )
    }
}
