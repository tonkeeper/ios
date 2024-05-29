import Foundation
import TKCore
import KeeperCore

struct SwapSettingsAssembly {
  private init() {}
  static func module(settings: SwapSettings,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<SwapSettingsViewController, SwapSettingsModuleOutput, Void> {
    let viewModel = SwapSettingsViewModelImplementation(
      settings: settings,
      swapSettingsController: keeperCoreMainAssembly.swapSettingsController()
    )
    let viewController = SwapSettingsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: ())
  }
}
