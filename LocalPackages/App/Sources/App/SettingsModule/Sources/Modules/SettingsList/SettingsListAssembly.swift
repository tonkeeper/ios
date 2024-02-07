import Foundation
import KeeperCore

struct SettingsListAssembly {
  private init() {}
  static func module(itemsProvider: SettingsListItemsProvider)
  -> (viewController: SettingsListViewController, output: SettingsListModuleOutput) {
    let viewModel = SettingsListViewModelImplementation(itemsProvider: itemsProvider)
    let viewController = SettingsListViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
