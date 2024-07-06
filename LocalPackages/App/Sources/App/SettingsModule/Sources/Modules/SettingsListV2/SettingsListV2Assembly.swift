import Foundation
import KeeperCore

struct SettingsListV2Assembly {
  private init() {}
  static func module(configurator: SettingsListV2Configurator)
  -> (viewController: SettingsListV2ViewController, output: SettingsListV2ModuleOutput) {
    let viewModel = SettingsListV2ViewModelImplementation(configurator: configurator)
    let viewController = SettingsListV2ViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
