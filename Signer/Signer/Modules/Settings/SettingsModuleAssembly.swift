import Foundation

struct SettingsModuleAssembly {
  private init() {}
  static func module() -> Module<SettingsViewController, SettingsModuleOutput, Void> {
    let viewModel = SettingsViewModelImplementation()
    let viewController = SettingsViewController(viewModel: viewModel)
    return Module(view: viewController, output: viewModel, input: Void())
  }
}
