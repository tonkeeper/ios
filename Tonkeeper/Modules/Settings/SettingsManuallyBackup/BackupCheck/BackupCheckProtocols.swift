import Foundation

protocol BackupCheckModuleOutput: AnyObject {
  func didCheckBackup()
}

protocol BackupCheckModuleInput: AnyObject {}

protocol BackupCheckPresenterInput {
  func viewDidLoad()
  func validate(word: String, index: Int) -> Bool
  func didEnterMnemonic(_ mnemonic: [String])
}

protocol BackupCheckViewInput: AnyObject {
  func update(with model: BackupCheckView.Model)
  func showMnemonicValidationError()
}
