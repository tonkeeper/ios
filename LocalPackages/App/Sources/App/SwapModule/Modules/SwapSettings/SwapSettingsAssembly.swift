import UIKit
import TKCore
import KeeperCore

struct SwapSettingsAssembly {
  private init() {}
  static func module(swapSettingsController: SwapSettingsController,
                     swapSettingsModel: SwapSettingsModel) -> MVVMModule<SwapSettingsViewController, SwapSettingsModuleOutput, Void> {
    let viewModel = SwapSettingsViewModelImplementation(
      swapSettingsController: swapSettingsController,
      swapSettingsModel: swapSettingsModel
    )
    
    let viewController = SwapSettingsViewController(
      viewModel: viewModel
    )
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
