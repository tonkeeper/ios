import Foundation
import TKCore
import KeeperCore

struct SettingsPurchasesAssembly {
  private init() {}
  static func module(wallet: Wallet, keeperCoreMainAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<SettingsPurchasesViewController, Void, Void> {
    let viewModel = SettingsPurchasesViewModelImplementation(
      model: SettingsPurchasesModel(
        wallet: wallet,
        walletNFTStore: keeperCoreMainAssembly.storesAssembly.walletNFTsStore,
        accountNFTsManagementStore: keeperCoreMainAssembly.storesAssembly.walletNFTsManagementStore(wallet: wallet)
      )
    )
    
    let viewController = SettingsPurchasesViewController(viewModel: viewModel)
    return .init(view: viewController, output: Void(), input: Void())
  }
}
