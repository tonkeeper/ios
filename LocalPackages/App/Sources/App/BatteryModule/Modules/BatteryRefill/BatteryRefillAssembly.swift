import UIKit
import TKCore
import KeeperCore

struct BatteryRefillAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<BatteryRefillViewController, BatteryRefillModuleOutput, BatteryRefillModuleInput> {
    let viewModel = BatteryRefillViewModelImplementation(
      wallet: wallet
    )
    
    let viewController = BatteryRefillViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: viewModel
    )
  }
}


