import UIKit
import TKCore
import KeeperCore

struct BatteryRefillSupportedTransactionsAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRefillSupportedTransactionsViewController, BatteryRefillSupportedTransactionsModuleOutput, BatteryRefillSupportedTransactionsModuleInput> {
    let viewModel = BatteryRefillSupportedTransactionsViewModelImplementation(
      wallet: wallet,
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration
    )
    
    let viewController = BatteryRefillSupportedTransactionsViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


