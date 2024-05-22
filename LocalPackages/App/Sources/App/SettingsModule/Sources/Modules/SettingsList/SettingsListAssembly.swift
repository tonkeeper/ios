import Foundation
import KeeperCore

struct SettingsListAssembly {
  private init() {}
  static func module(
    itemsProvider: SettingsListItemsProvider,
    showsBackButton: Bool = true
  ) -> (viewController: SettingsListViewController, output: SettingsListModuleOutput) {
    let viewModel = SettingsListViewModelImplementation(itemsProvider: itemsProvider, showsBackButton: showsBackButton)
    let viewController = SettingsListViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
