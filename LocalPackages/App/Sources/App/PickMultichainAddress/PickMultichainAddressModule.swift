import KeeperCore
import TKCoordinator
import TKCore
import UIKit

@MainActor
struct PickMultichainAddressModule {
    func makeCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        addresses: [MultichainWalletAddress]
    ) -> PickMultichainAddressCoordinator {
        PickMultichainAddressCoordinatorImplementation(
            router: router,
            addresses: addresses
        )
    }
}
