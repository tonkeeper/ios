import UIKit

struct SettingsBackupAssembly {
  static func module() -> (SettingsBackupViewController, SettingsBackupOutput) {
    let viewModel = SettingsBackupViewModelImplementation()
    let viewController = SettingsBackupViewController(viewModel: viewModel)
    
    return (viewController, viewModel)
  }
}
