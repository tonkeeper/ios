import UIKit
import TKCore
import KeeperCore

struct BatteryRefillSupportedTransactionsAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRefillSupportedTransactionsViewController, BatteryRefillSupportedTransactionsModuleOutput, BatteryRefillSupportedTransactionsModuleInput> {
    let viewModel = BatteryRefillSupportedTransactionsViewModelImplementation(
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


