import Foundation
import TKCore
import KeeperCore

@MainActor
struct SignRawConfirmationAssembly {
  private init() {}
  static func module(
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) -> MVVMModule<SignRawConfirmationViewController, SignRawConfirmationModuleOutput, Void> {
    let viewModel = SignRawConfirmationViewModelImplementation()
    let viewController = SignRawConfirmationViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
