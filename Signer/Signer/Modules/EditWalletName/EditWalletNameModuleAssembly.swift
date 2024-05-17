import Foundation

struct EditWalletNameModuleAssembly {
  private init() {}
  static func module(configurator: EditWalletNameViewModelConfigurator, defaultName: String?) -> Module<EditWalletNameViewController, EditWalletNameModuleOutput, Void> {
    let viewModel = EditWalletNameViewModelImplementation(configurator: configurator, defaultName: defaultName)
    let viewController = EditWalletNameViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
