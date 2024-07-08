import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

final class SettingsListBackupConfigurator: SettingsListV2Configurator {
  
  var didTapShowRecoveryPhrase: (() -> Void)?
  var didTapBackupManually: (() -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListV2State) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  var title: String { TKLocales.Backup.title }
  var isSelectable: Bool { false }
  
  func getState() -> SettingsListV2State {
    guard let wallet = walletsStore.getState().wallets.first(where: { $0.id == walletId }) else {
      return SettingsListV2State(sections: [], selectedItem: nil)
    }
    return createState(wallet: wallet)
  }
  
  // MARK: - Dependencies
 
  private let walletId: String
  private let walletsStore: WalletsStoreV2
  private let dateFormatter: DateFormatter
  
  // MARK: - Init
  
  init(walletId: String,
       walletsStore: WalletsStoreV2,
       dateFormatter: DateFormatter) {
    self.walletId = walletId
    self.walletsStore = walletsStore
    self.dateFormatter = dateFormatter
    
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      guard let wallet = newState.wallets.first(where: { $0.id == walletId }) else { return }
      let state = observer.createState(wallet: wallet)
      observer.didUpdateState?(state)
    }
  }
}

private extension SettingsListBackupConfigurator {
  func createState(wallet: Wallet) -> SettingsListV2State {
    var sections = [SettingsListV2Section]()
    sections.append(createDescriptionSection())
    
    if wallet.isBackupAvailable {
      if let backupDate = wallet.setupSettings.backupDate {
        sections.append(createBackupDoneSection(date: backupDate))
        sections.append(createCreateRecoveryPhraseSection())
      } else {
        sections.append(createBackupManuallySection())
      }
    }
    
    return SettingsListV2State(
      sections: sections,
      selectedItem: nil
    )
  }
  
  func createDescriptionSection() -> SettingsListV2Section {
    SettingsListV2Section.items(
      topPadding: 0,
      items: [],
      header: TKLocales.Backup.Information.title,
      bottomDescription: SettingsTextDescriptionView.Model(
        padding: UIEdgeInsets(top: 0, left: 1, bottom: 14, right: 1),
        text: TKLocales.Backup.Information.subtitle
      )
    )
  }
  
  func createBackupManuallySection() -> SettingsListV2Section {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    configuration.content = TKButton.Configuration.Content(
      title: .plainString(TKLocales.Backup.Manually.button)
    )
    configuration.action = { [didTapBackupManually] in
      didTapBackupManually?()
    }
    return SettingsListV2Section.items(
      topPadding: 0,
      items: [
        TKButtonCell.Model(
          id: .backupManualyItemIdentifier,
          configuration: configuration,
          padding: UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0),
          mode: .full
        )
      ],
      header: nil,
      bottomDescription: nil
    )
  }
  
  func createBackupDoneSection(date: Date) -> SettingsListV2Section {
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .short
    let subtitle = dateFormatter.string(from: date)
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: TKLocales.Backup.Done.title.withTextStyle(.label1, color: .Text.primary, alignment: .left),
        tagViewModel: nil,
        subtitle: subtitle.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
        description: nil
      ),
      rightItemConfiguration: nil,
      isVerticalCenter: false
    )
    
    let iconConfiguration: TKUIListItemIconView.Configuration.IconConfiguration = .image(
      TKUIListItemImageIconView.Configuration(
        image: .image(.App.Icons.Size28.donemark),
        tintColor: .white,
        backgroundColor: .Accent.green,
        size: CGSize(width: 44, height: 44),
        cornerRadius: 22
      )
    )

    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: iconConfiguration,
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .image(
        TKUIListItemImageAccessoryView.Configuration(
          image: .TKUIKit.Icons.Size16.chevronRight,
          tintColor: .Icon.tertiary,
          padding: .zero
        )
      )
    )
    
    let item = TKUIListItemCell.Configuration(
      id: .backupDoneItemIdentifier,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: false,
      selectionClosure: nil
    )
    
    return SettingsListV2Section.items(
      topPadding: 0,
      items: [item],
      header: nil,
      bottomDescription: nil
    )
  }
  
  func createCreateRecoveryPhraseSection() -> SettingsListV2Section {
    let items = [
      TKUIListItemCell.Configuration.createSettingsItem(
        id: .changePasscodeItemIdentifier,
        title: .string(TKLocales.Backup.ShowPhrase.title),
        accessory: .icon(.TKUIKit.Icons.Size28.key, .Accent.blue),
        selectionClosure: { [didTapShowRecoveryPhrase] in
          didTapShowRecoveryPhrase?()
        }
      )
    ]
    
    return SettingsListV2Section.items(
      topPadding: 16,
      items: items
    )
  }
}

private extension String {
  static let biometryItemIdentifier = "BiometryItem"
  static let locksreenItemIdentifier = "LockScreenItem"
  static let changePasscodeItemIdentifier = "ChangePasscodeItem"
  static let backupManualyItemIdentifier = "BackupManuallyItem"
  static let backupDoneItemIdentifier = "BackupDoneItem"
  static let showRecoveryPhraseItemIdentifier = "showRecoveryPhraseItem"
}

private extension String {
  static let faceId = "Face ID"
  static let touchId = "Touch ID"
}

