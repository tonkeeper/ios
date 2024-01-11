import UIKit

protocol SettingsBackupOutput: AnyObject {
  var didTapBackupManually: (() -> Void)? { get set }
  var didTapShowRecoveryPhrase: (() -> Void)? { get set }
  var confirmation: (() async -> Bool)? { get set }
}

protocol SettingsBackupViewModel: AnyObject {
  var didUpdateModel: ((SettingsBackupView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SettingsBackupViewModelImplementation: SettingsBackupViewModel, SettingsBackupOutput {
  
  var didTapBackupManually: (() -> Void)?
  var didTapShowRecoveryPhrase: (() -> Void)?
  var confirmation: (() async -> Bool)?
  
  var didUpdateModel: ((SettingsBackupView.Model) -> Void)?
  
  private let appSettings = AppSettings()
  
  init() {
    NotificationCenter.default
      .addObserver(
        self,
        selector: #selector(viewDidLoad),
        name: Notification.Name("isNeedToMakeBackupUpdated"), object: nil
      )
  }
  
  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name("isNeedToMakeBackupUpdated"),
      object: nil)
  }
  
  @objc
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
}

private extension SettingsBackupViewModelImplementation {
  func createModel() -> SettingsBackupView.Model {
    
    var backupManuallyButtonModel: SettingsBackupView.Model.BackupManuallyButtonModel?
    if !appSettings.isWalletImported && appSettings.isNeedToMakeBackup {
      backupManuallyButtonModel = SettingsBackupView.Model.BackupManuallyButtonModel(
        title: "Back Up Manually",
        action: { [weak self] in
          self?.backupManually()
        }
      )
    }
    
    var backupDateViewModel: SettingsBackupDateView.Model?
    if !appSettings.isWalletImported, let date = appSettings.backUpDate {
      let dateFormatter = DateFormatter()
      dateFormatter.locale = Locale.init(identifier: "EN")
      dateFormatter.dateFormat = "MMM d yyyy, H:mm"
      let subtitle = "Last backup \(dateFormatter.string(from: date))"
      backupDateViewModel = SettingsBackupDateView.Model(title: "Manual Backup On",
                                                         subtitle: subtitle)
    }
    
    var showRecoveryPhraseButtonModel: SettingsListCellContentView.Model?
    if appSettings.isWalletImported || !appSettings.isNeedToMakeBackup {
      showRecoveryPhraseButtonModel = SettingsListCellContentView.Model(
        title: "Show Recovery Phrase",
        subtitle: nil,
        accessoryModel: SettingsListCellAccessoryView.Model.icon(.init(image: .Icons.SettingsList.security, tintColor: .Accent.blue)),
        isBadgeVisible: false,
        handler: { [weak self] in
          guard let self = self else { return }
          Task {
            let isConfirmed = await self.confirmation?() ?? false
            guard isConfirmed else { return }
            await MainActor.run {
              self.didTapShowRecoveryPhrase?()
            }
          }
        })
    }
    
    return SettingsBackupView.Model(
      title: "Manual",
      subtitle: "Back up your wallet manually by writing down the recovery phrase.",
      backupManuallyButtonModel: backupManuallyButtonModel,
      backupDateViewModel: backupDateViewModel,
      showRecoveryPhraseButtonModel: showRecoveryPhraseButtonModel
    )
  }
  
  func backupManually() {
    Task {
      let isConfirmed = await self.confirmation?() ?? false
      guard isConfirmed else { return }
      await MainActor.run {
        self.didTapBackupManually?()
      }
    }
  }
}
