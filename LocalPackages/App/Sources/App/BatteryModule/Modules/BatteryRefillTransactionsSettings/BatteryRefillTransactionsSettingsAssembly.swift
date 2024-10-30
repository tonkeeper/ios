import UIKit
import TKCore
import KeeperCore

struct BatteryRefillTransactionsSettingsAssembly {
  private init() {}
  static func module(keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRefillTransactionsSettingsViewController, BatteryRefillTransactionsSettingsModuleOutput, BatteryRefillTransactionsSettingsModuleInput> {
    let viewModel = BatteryRefillTransactionsSettingsViewModelImplementation(
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
      keeperInfoStore: keeperCoreMainAssembly.storesAssembly.keeperInfoStore
    )
    
    let viewController = BatteryRefillTransactionsSettingsViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


