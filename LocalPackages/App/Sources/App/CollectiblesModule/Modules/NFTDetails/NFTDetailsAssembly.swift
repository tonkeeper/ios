import Foundation
import TKCore
import KeeperCore

struct NFTDetailsAssembly {
  private init() {}
  static func module(
    nft: NFT,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<NFTDetailsViewController, NFTDetailsModuleOutput, Void> {
    let viewModel = NFTDetailsViewModelImplementation(nft: nft)
    let viewController = NFTDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
