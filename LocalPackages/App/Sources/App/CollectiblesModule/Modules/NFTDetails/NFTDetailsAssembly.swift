import Foundation
import TKCore
import KeeperCore

struct NFTDetailsAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    nft: NFT,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<NFTDetailsViewController, NFTDetailsModuleOutput, NFTDetailsModuleInput> {
    let viewModel = NFTDetailsViewModelImplementation(
      nft: nft,
      wallet: wallet,
      dnsService: keeperCoreMainAssembly.servicesAssembly.dnsService(),
      mnemonicRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository()
    )
    let viewController = NFTDetailsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
