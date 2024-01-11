import UIKit

final class SettingsBackupViewController: GenericViewController<SettingsBackupView> {
  private let viewModel: SettingsBackupViewModel
  
  init(viewModel: SettingsBackupViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Backup"
    navigationItem.largeTitleDisplayMode = .never
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SettingsBackupViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
  }
}
