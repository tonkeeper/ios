import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

final class SettingsBackupListItemsProvider: SettingsListItemsProvider {
  typealias BackupInformationCellRegistration = UICollectionView.CellRegistration<SettingsBackupStateCell, SettingsBackupStateCell.Model>
  
  public var didTapShowRecoveryPhrase: (() -> Void)?
  public var didTapBackupManually: (() -> Void)?
  
  private let backupInformationCellRegistration: BackupInformationCellRegistration

  private let backupController: BackupController
  
  init(backupController: BackupController) {
    self.backupController = backupController
    
    let backupInformationCellRegistration = BackupInformationCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.backupInformationCellRegistration = backupInformationCellRegistration
    
    backupController.didUpdateBackupState = { [weak self] in
      self?.didUpdateSections?()
    }
  }
  
  var didUpdateSections: (() -> Void)?
  
  var title: String { "Backup" }
  
  func getSections() -> [SettingsListSection] {
    setupSettingsSections()
  }
  
  func selectItem(section: SettingsListSection, index: Int) {}
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    switch itemIdentifier {
    case let model as SettingsBackupStateCell.Model:
      let cell = collectionView.dequeueConfiguredReusableCell(using: backupInformationCellRegistration, for: indexPath, item: model)
      return cell
    default: return nil
    }
  }
}

private extension SettingsBackupListItemsProvider {
  func setupSettingsSections() -> [SettingsListSection] {
    let backupModel = backupController.getBackupModel()
    var sections = [SettingsListSection]()
    sections.append(setupBackupStateSection(model: backupModel))
    
    switch backupModel.backupState {
    case .backedUp:
      sections.append(setupShowRecoveryPhraseSection())
    case .notBackedUp:
      break
    }

    return sections
  }
  
  func setupBackupStateSection(model: BackupController.BackupModel) -> SettingsListSection {
    var items: [AnyHashable] = [SettingsTextCell.Model(
      id: .backupInformationTitle,
        padding: UIEdgeInsets(top: 14, left: 0, bottom: 0, right: 0),
        text: String.backupInformationTitle.withTextStyle(
          .h3,
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        ),
      numberOfLines: 1
    ),
    SettingsTextCell.Model(
      id: .backupInformationSubtitle,
      padding: UIEdgeInsets(top: 4, left: 0, bottom: 14, right: 0),
      text: String.backupInformationSubtitle.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      ),
      numberOfLines: 0
    )]
    
    switch model.backupState {
    case .notBackedUp:
      var backupButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
        category: .secondary,
        size: .large
      )
      backupButtonConfiguration.content.title = .plainString(.backupManualyButtonTitle)
      backupButtonConfiguration.action = { [weak self] in
        self?.didTapBackupManually?()
      }
      items.append(
        SettingsButtonCell.Model(
          id: .backupManualyButtonTitle,
          padding: UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0),
          buttons: [
            backupButtonConfiguration
          ]
        )
      )
    case .backedUp(let date):
      items.append(
        SettingsBackupStateCell.Model(
            title: "Manual Backup On",
            subtitle: "Last backup \(date)"
        )
      )
    }
    
    return SettingsListSection(
      padding: NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: 16,
        trailing: 16
      ),
      items: items
    )
  }
  
  func setupShowRecoveryPhraseSection() -> SettingsListSection {
    SettingsListSection(
      padding: NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16) ,
      items: [
        SettingsCell.Model(
          identifier: .showRecoveryPhraseItemTitle,
          selectionHandler: {[weak self] in
            self?.didTapShowRecoveryPhrase?()
          },
          cellContentModel: SettingsCellContentView.Model(
            title: .showRecoveryPhraseItemTitle,
            icon: .TKUIKit.Icons.Size28.key,
            tintColor: .Accent.blue
          )
        )
      ])
  }
}

private extension String {
  static let backupInformationTitle = TKLocales.Backup.Information.title
  static let backupInformationSubtitle = TKLocales.Backup.Information.subtitle
  static let backupManualyButtonTitle = TKLocales.Backup.Manually.button
  static let backupStateIdentifier = "BackupState"
  static let showRecoveryPhraseItemTitle = TKLocales.Backup.ShowPhrase.title
}
