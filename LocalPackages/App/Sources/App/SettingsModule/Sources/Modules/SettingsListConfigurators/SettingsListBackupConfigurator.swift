import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

final class SettingsListBackupConfigurator: SettingsListConfigurator {
  
  var didTapShowRecoveryPhrase: (() -> Void)?
  var didTapBackupManually: (() -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  
  var title: String { TKLocales.Backup.title }
  
  func getInitialState() -> SettingsListState {
    createState()
  }

  // MARK: - Dependencies
 
  private var wallet: Wallet
  private let walletsStore: WalletsStore
  private let dateFormatter: DateFormatter
  
  // MARK: - Init
  
  init(wallet: Wallet,
       walletsStore: WalletsStore,
       dateFormatter: DateFormatter) {
    self.wallet = wallet
    self.walletsStore = walletsStore
    self.dateFormatter = dateFormatter
    
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      DispatchQueue.main.async {
        guard let updatedWallet = newState.wallets.first(where: { $0.id == wallet.id }) else { return }
        self.wallet = updatedWallet
        let state = observer.createState()
        observer.didUpdateState?(state)
      }
    }
  }
  
  private func createState() -> SettingsListState {
    var sections = [
      createBackupSection()
    ]
    
    if let showRecoveryPhraseSection = createShowRecoveryPhraseSection() {
      sections.append(showRecoveryPhraseSection)
    }
    return SettingsListState(
      sections: sections
    )
  }
  
  private func createBackupSection() -> SettingsListSection {
    var items = [AnyHashable]()
    if let backupDate = wallet.setupSettings.backupDate {
      items.append(createBackUpOnItem(date: backupDate))
    } else {
      items.append(createBackupManuallyItem())
    }
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 16,
      headerConfiguration: SettingsListSectionHeaderView.Configuration(
        title: TKLocales.Backup.Information.title,
        caption: TKLocales.Backup.Information.subtitle
      )
    ))
  }
  
  private func createShowRecoveryPhraseSection() -> SettingsListSection? {
    guard wallet.setupSettings.backupDate != nil else { return nil }
    let items = [createShowRecoveryPhraseItem()]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 16
    ))
  }
  
  private func createBackUpOnItem(date: Date) -> SettingsListItem {
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .short
    let caption = dateFormatter.string(from: date)
    
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentViewV2.Configuration(
        iconViewConfiguration: TKListItemIconViewV2.Configuration(
          content: .image(
            TKImageView.Model(
              image: .image(.App.Icons.Size28.donemark),
              tintColor: .white,
              size: .auto,
              corners: .none,
              padding: .zero
            )
          ),
          alignment: .center,
          cornerRadius: 22,
          backgroundColor: .Accent.green,
          size: CGSize(width: 44, height: 44)
        ),
        textContentViewConfiguration: TKListItemTextContentViewV2.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: TKLocales.Backup.Done.title
          ),
          captionViewsConfigurations: [TKListItemTextView.Configuration(
            text: caption,
            color: .Text.secondary,
            textStyle: .body2
          )]
        )
      )
    )
    
    return SettingsListItem(
      id: .backupDoneItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .chevron,
      onSelection: { _ in
        
      }
    )
  }
  
  private func createBackupManuallyItem() -> SettingsButtonListItem {
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    buttonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(TKLocales.Backup.Manually.button)
    )
    buttonConfiguration.action = { [didTapBackupManually] in
      didTapBackupManually?()
    }
    
    return SettingsButtonListItem(
      id: .backupManualyItemIdentifier,
      cellConfiguration: TKButtonCollectionViewCell.Configuration(
        buttonConfiguration: buttonConfiguration
      )
    )
  }
  
  private func createShowRecoveryPhraseItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentViewV2.Configuration(
        textContentViewConfiguration: TKListItemTextContentViewV2.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: TKLocales.Backup.ShowPhrase.title
          )
        )
      )
    )
    
    return SettingsListItem(
      id: .backupDoneItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.key, tintColor: .Accent.blue)),
      onSelection: { [weak self] _ in
        self?.didTapShowRecoveryPhrase?()
      }
    )
  }
}
private extension String {
  static let backupManualyItemIdentifier = "BackupManuallyItem"
  static let backupDoneItemIdentifier = "BackupDoneItem"
  static let showRecoveryPhraseItemIdentifier = "showRecoveryPhraseItem"
}
