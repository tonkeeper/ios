import Foundation
import TKCore
import KeeperCore

struct StakingOptionsAssembly {
  
  static func module(
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<StakingOptionsViewController, StakingOptionsModuleOutput, Void> {
    let viewModel = StakingOptionsViewModelImplementation()
    let viewController = StakingOptionsViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
