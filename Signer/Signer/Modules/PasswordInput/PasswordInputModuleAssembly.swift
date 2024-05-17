import Foundation

struct PasswordInputModuleAssembly {
  private init() {}
  static func module(configurator: PasswordInputViewModelConfigurator) -> Module<PasswordInputViewController, PasswordInputModuleOutput, Void> {
    let viewModel = PasswordInputViewModelImplementation(
      configurator: configurator
    )
    let viewController = PasswordInputViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
