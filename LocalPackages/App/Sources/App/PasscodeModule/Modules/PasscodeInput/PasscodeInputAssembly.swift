import Foundation

struct PasscodeInputAssembly {
  private init() {}
  static func module(title: String)
  -> (viewController: PasscodeInputViewController, output: PasscodeInputModuleOutput, input: PasscodeInputModuleInput) {
    let viewModel = PasscodeInputViewModelImplementation(title: title)
    let viewController = PasscodeInputViewController(viewModel: viewModel)
    return (viewController, viewModel, viewModel)
  }
}
