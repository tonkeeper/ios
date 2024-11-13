import Foundation
import TKCore
import KeeperCore

struct NFTDetailsManageNFTAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    nft: NFT,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<NFTDetailsManageNFTViewController, NFTDetailsManageNFTOutput, Void> {
    let viewController = NFTDetailsManageNFTViewController(
      wallet: wallet,
      nft: nft,
      nftManagementStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet),
      nftService: keeperCoreMainAssembly.servicesAssembly.nftService()
    )
    
    return MVVMModule(view: viewController, output: viewController, input: Void())
  }
}
