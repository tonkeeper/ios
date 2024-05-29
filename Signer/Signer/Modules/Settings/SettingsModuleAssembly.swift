import Foundation

struct SettingsModuleAssembly {
  private init() {}
  static func module(itemsProvider: SettingsLiteItemsProvider) -> Module<SettingsViewController, SettingsModuleOutput, Void> {
    let viewModel = SettingsViewModelImplementation(itemsProvider: itemsProvider)
    let viewController = SettingsViewController(viewModel: viewModel)
    return Module(view: viewController, output: viewModel, input: Void())
  }
}
