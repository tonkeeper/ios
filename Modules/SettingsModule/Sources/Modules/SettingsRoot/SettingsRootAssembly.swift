import Foundation
import KeeperCore

public struct SettingsRootAssembly {
  private init() {}
//  public static func module(settingsController: SettingsController)
//  -> (viewController: SettingsRootViewController, output: SettingsRootModuleOutput) {
//    let viewModel = SettingsRootViewModelImplementation(settingsController: settingsController)
//    let viewController = SettingsRootViewController(viewModel: viewModel)
//    return (viewController, viewModel)
//  }
//  
  public static func module()
  -> (viewController: SettingsRootViewController, output: SettingsRootModuleOutput) {
    let viewModel = SettingsRootViewModelImplementation()
    let viewController = SettingsRootViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
