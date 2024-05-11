import Foundation

struct SettingsModuleAssembly {
  private init() {}
  static func module(urlOpener: URLOpener) -> Module<SettingsViewController, SettingsModuleOutput, Void> {
    let viewModel = SettingsViewModelImplementation(urlOpener: urlOpener)
    let viewController = SettingsViewController(viewModel: viewModel)
    return Module(view: viewController, output: viewModel, input: Void())
  }
}
