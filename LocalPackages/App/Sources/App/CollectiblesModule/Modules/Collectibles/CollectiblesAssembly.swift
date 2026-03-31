import Foundation
import KeeperCore
import TKCore

@MainActor
struct CollectiblesAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        collectiblesListViewController: CollectiblesListViewController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<CollectiblesViewController, CollectiblesModuleOutput, CollectiblesModuleInput> {
        let viewModel = CollectiblesViewModelImplementation(
            wallet: wallet,
            walletNFTsStore: keeperCoreMainAssembly.storesAssembly.walletNFTsStore(wallet: wallet, nftService: keeperCoreMainAssembly.servicesAssembly.accountNftService()),
            backgroundUpdate: keeperCoreMainAssembly.backgroundUpdateAssembly.backgroundUpdate
        )
        let viewController = CollectiblesViewController(
            viewModel: viewModel,
            collectiblesListViewController: collectiblesListViewController
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}
