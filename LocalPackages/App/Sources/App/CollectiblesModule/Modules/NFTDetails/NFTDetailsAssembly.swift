import Foundation
import TKCore
import KeeperCore

struct NFTDetailsAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    nft: NFT,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<NFTDetailsViewController, NFTDetailsModuleOutput, Void> {
    
    
    let nftManagement = NFTDetailsManageNFTAssembly.module(
      wallet: wallet,
      nft: nft,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    let viewModel = NFTDetailsViewModelImplementation(
      nft: nft,
      wallet: wallet,
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
      dnsService: keeperCoreMainAssembly.servicesAssembly.dnsService(),
      appSetttingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      walletNftManagementStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
      nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
      nftDetailsManageNFTOutput: nftManagement.output
    )
    let viewController = NFTDetailsViewController(
      viewModel: viewModel,
      manageNFTViewController: nftManagement.view
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
