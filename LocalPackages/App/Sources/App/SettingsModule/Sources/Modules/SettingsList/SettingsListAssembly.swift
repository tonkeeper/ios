import Foundation
import KeeperCore

struct SettingsListAssembly {
  private init() {}
  static func module(configurator: SettingsListConfigurator)
  -> (viewController: SettingsListViewController, output: SettingsListModuleOutput) {
    let viewModel = SettingsListViewModelImplementation(configurator: configurator)
    let viewController = SettingsListViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
