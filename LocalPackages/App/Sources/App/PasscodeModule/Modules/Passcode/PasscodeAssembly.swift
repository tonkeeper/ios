import UIKit
import TKCore

struct PasscodeAssembly {
  private init() {}
  public static func module(navigationController: UINavigationController)
  -> MVVMModule<PasscodeViewController, PasscodeModuleOutput, PasscodeModuleInput> {
    let viewModel = PasscodeViewModelImplementation()
    let viewController = PasscodeViewController(
      viewModel: viewModel,
      inputNavigationController: navigationController
    )
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
