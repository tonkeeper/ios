import Foundation
import KeeperCore
import TKCore

struct NFTDetailsAssembly {
    private init() {}
    @MainActor
    static func module(
        wallet: Wallet,
        nft: NFT,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        navigationButton: NFTDetailsNavigationButton = .swipeDown
    ) -> MVVMModule<NFTDetailsViewController, NFTDetailsModuleOutput, Void> {
        let walletNftManagementStore = keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet)
        let nftService = keeperCoreMainAssembly.servicesAssembly.nftService()

        let viewModel = NFTDetailsViewModelImplementation(
            nft: nft,
            wallet: wallet,
            navigationButton: navigationButton,
            dnsService: keeperCoreMainAssembly.servicesAssembly.dnsService(),
            appSetttingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            walletNftManagementStore: walletNftManagementStore,
            manageNFTModel: NFTDetailsManageNFTModel(
                wallet: wallet,
                nft: nft,
                nftManagementStore: walletNftManagementStore,
                nftService: nftService
            )
        )
        let viewController = NFTDetailsViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
