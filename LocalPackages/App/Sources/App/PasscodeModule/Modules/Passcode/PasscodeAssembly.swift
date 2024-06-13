import UIKit
import TKCore

struct PasscodeAssembly {
  private init() {}
  public static func module(navigationController: UINavigationController,
                            isBiometryTurnedOn: Bool)
  -> MVVMModule<PasscodeViewController, PasscodeModuleOutput, PasscodeModuleInput> {
    let viewModel = PasscodeViewModelImplementation(isBiometryTurnedOn: isBiometryTurnedOn)
    let viewController = PasscodeViewController(
      viewModel: viewModel,
      inputNavigationController: navigationController
    )
    return MVVMModule(view: viewController, output: viewModel, input: viewModel)
  }
}
