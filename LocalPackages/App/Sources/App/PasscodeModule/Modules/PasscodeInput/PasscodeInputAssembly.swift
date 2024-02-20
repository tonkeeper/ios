import Foundation

public struct PasscodeInputAssembly {
  private init() {}
  public static func module(title: String,
                            validator: PasscodeInputValidator,
                            biometryProvider: PasscodeInputBiometryProvider)
  -> (viewController: PasscodeInputViewController, output: PasscodeInputModuleOutput, input: PasscodeInputModuleInput) {
    let viewModel = PasscodeInputViewModelImplementation(
      title: title,
      validator: validator,
      biometryProvider: biometryProvider)
    let viewController = PasscodeInputViewController(viewModel: viewModel)
    return (viewController, viewModel, viewModel)
  }
}
