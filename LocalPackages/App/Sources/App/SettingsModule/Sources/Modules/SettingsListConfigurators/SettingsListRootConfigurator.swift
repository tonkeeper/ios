import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListRootConfigurator: SettingsListV2Configurator {

  var didTapEditWallet: ((Wallet) -> Void)?
  var didTapCurrencySettings: (() -> Void)?
  var didOpenURL: ((URL) -> Void)?
  var didShowAlert: ((_ title: String,
                      _ description: String?,
                      _ actions: [UIAlertAction]) -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListV2State) -> Void)?
  
  var title: String { TKLocales.Settings.title }
  var isSelectable: Bool { false }
  
  func getState() -> SettingsListV2State {
    guard let wallet = walletsStore.getState().wallets.first(where: { $0.id == walletId }) else {
      return SettingsListV2State(sections: [], selectedItem: nil)
    }
    let sections = createSections(wallet: wallet)
    return SettingsListV2State(sections: sections, selectedItem: nil)
  }
  
  // MARK: - State
  
  private let actor = SerialActor<Void>()
  
  // MARK: - Dependencies
  
  private let walletId: String
  private let walletsStore: WalletsStoreV2
  private let currencyStore: CurrencyStoreV2
  private let mnemonicsRepository: MnemonicsRepository
  private let appStoreReviewer: AppStoreReviewer
  private let configurationStore: ConfigurationStore
  
  // MARK: - Init
  
  init(walletId: String,
       walletsStore: WalletsStoreV2,
       currencyStore: CurrencyStoreV2,
       mnemonicsRepository: MnemonicsRepository,
       appStoreReviewer: AppStoreReviewer,
       configurationStore: ConfigurationStore) {
    self.walletId = walletId
    self.walletsStore = walletsStore
    self.currencyStore = currencyStore
    self.mnemonicsRepository = mnemonicsRepository
    self.appStoreReviewer = appStoreReviewer
    self.configurationStore = configurationStore
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      guard let wallet = newState.wallets.first(where: { $0.id == walletId }) else { return }
      guard wallet != oldState?.wallets.first(where: { $0.id == walletId }) else { return }
      let sections = observer.createSections(wallet: wallet)
      observer.didUpdateState?(SettingsListV2State(sections: sections, selectedItem: nil))
    }
  }
}

private extension SettingsListRootConfigurator {
  func createSections(wallet: Wallet) -> [SettingsListV2Section] {
    let currency = currencyStore.getState()
    
    var sections = [SettingsListV2Section]()
    
    sections.append(createWalletSection(wallet: wallet))
    
    if let securitySection = createSecuritySection(wallet: wallet) {
      sections.append(securitySection)
    }
    
    sections.append(createSettingsSection(currency: currency))
    sections.append(createInformationSection())
    sections.append(createDeleteSection(wallet: wallet))
    
    return sections
  }
  
  func createWalletSection(wallet: Wallet) -> SettingsListV2Section {
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: wallet.label.withTextStyle(
          .label1,
          color: .Text.primary,
          alignment: .left
        ),
        tagViewModel: wallet.listTagConfiguration(),
        subtitle: TKLocales.Settings.Items.setup_wallet_description.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .left
        ),
        description: nil
      ),
      rightItemConfiguration: nil
    )
    
    let iconConfiguration: TKUIListItemIconView.Configuration.IconConfiguration
    switch wallet.icon {
    case .emoji(let emoji):
      iconConfiguration = .emoji(TKUIListItemEmojiIconView.Configuration(
        emoji: emoji,
        backgroundColor: wallet.tintColor.uiColor
      ))
    case .icon(let image):
      iconConfiguration = .image(TKUIListItemImageIconView.Configuration(
        image: .image(image.image),
        tintColor: .white,
        backgroundColor: wallet.tintColor.uiColor,
        size: CGSize(width: 44, height: 44),
        cornerRadius: 22,
        contentMode: .scaleAspectFit,
        imageSize: CGSize(width: 22, height: 22)
      ))
    }

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
    
    let configuration = TKUIListItemCell.Configuration(
      id: .walletIdentifier,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: true,
      selectionClosure: { [weak self] in
        guard let self = self else { return }
        self.didTapEditWallet?(wallet)
      }
    )
    
    return SettingsListV2Section.items(topPadding: 14, items: [configuration])
  }
  
  func createSecuritySection(wallet: Wallet) -> SettingsListV2Section? {
    guard mnemonicsRepository.hasMnemonics() else { return nil }
    
    var items = [AnyHashable]()
    items.append(
      TKUIListItemCell.Configuration.createSettingsItem(
        id: .securityItemIdentifier,
        title: .string(TKLocales.Settings.Items.security),
        accessory: .icon(.TKUIKit.Icons.Size28.key, .Accent.blue),
        selectionClosure: {
          
        }
      )
    )
    
    if wallet.isBackupAvailable {
      items.append(
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .backupItemIdentifier,
          title: .string(TKLocales.Settings.Items.backup),
          accessory: .icon(.TKUIKit.Icons.Size28.lock, .Accent.blue),
          selectionClosure: {
            
          }
        )
      )
    }
    return SettingsListV2Section.items(topPadding: 16, items: items)
  }
  
  func createSettingsSection(currency: Currency) -> SettingsListV2Section {
    return SettingsListV2Section.items(
      topPadding: 16,
      items: [
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .currencyItemIdentifier,
          title: .string(TKLocales.Settings.Items.currency),
          accessory: .text(value: currency.code),
          selectionClosure: { [weak self] in
            self?.didTapCurrencySettings?()
          }
        ),
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .themeItemIdentifier,
          title: .string(TKLocales.Settings.Items.theme),
          accessory: .text(value: TKThemeManager.shared.theme.title),
          selectionClosure: {
            
          }
        )
      ]
    )
  }
  
  func createInformationSection() -> SettingsListV2Section {
    return SettingsListV2Section.items(
      topPadding: 16,
      items: [
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .FAQItemIdentifier,
          title: .string(TKLocales.Settings.Items.faq),
          accessory: .icon(.TKUIKit.Icons.Size28.question, .Accent.blue),
          selectionClosure: { [weak self, configurationStore] in
            guard let self else { return }
            Task {
              guard let contactUsURL = try? await configurationStore
                .getConfiguration()
                .faqUrl else {
                return
              }
              await MainActor.run {
                self.didOpenURL?(contactUsURL)
              }
            }
          }
        ),
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .supportItemIdentifier,
          title: .string(TKLocales.Settings.Items.support),
          accessory: .icon(.TKUIKit.Icons.Size28.telegram, .Accent.blue),
          selectionClosure: { [weak self, configurationStore] in
            guard let self else { return }
            Task {
              guard let contactUsURL = try? await configurationStore
                .getConfiguration()
                .directSupportUrl else {
                return
              }
              await MainActor.run {
                self.didOpenURL?(contactUsURL)
              }
            }
          }
        ),
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .tonkeeperNewsItemIdentifier,
          title: .string(TKLocales.Settings.Items.tk_news),
          accessory: .icon(.TKUIKit.Icons.Size28.telegram, .Icon.secondary),
          selectionClosure: { [weak self, configurationStore] in
            guard let self else { return }
            Task {
              guard let contactUsURL = try? await configurationStore
                .getConfiguration()
                .tonkeeperNewsUrl else {
                return
              }
              await MainActor.run {
                self.didOpenURL?(contactUsURL)
              }
            }
          }
        ),
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .contactUsItemIdentifier,
          title: .string(TKLocales.Settings.Items.contact_us),
          accessory: .icon(.TKUIKit.Icons.Size28.messageBubble, .Icon.secondary),
          selectionClosure: { [weak self, configurationStore] in
            guard let self else { return }
            Task {
              guard let contactUsURL = try? await configurationStore
                .getConfiguration()
                .supportLink else {
                return
              }
              await MainActor.run {
                self.didOpenURL?(contactUsURL)
              }
            }
          }
        ),
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .rateItemIdentifier,
          title: .string(TKLocales.Settings.Items.rate(InfoProvider.appName())),
          accessory: .icon(.TKUIKit.Icons.Size28.star, .Icon.secondary),
          selectionClosure: { [weak self] in
            self?.appStoreReviewer.requestReview()
          }
        ),
        TKUIListItemCell.Configuration.createSettingsItem(
          id: .legalItemIdentifier,
          title: .string(TKLocales.Settings.Items.legal),
          accessory: .icon(.TKUIKit.Icons.Size28.doc, .Icon.secondary),
          selectionClosure: {
            
          }
        )
      ]
    )
  }
  
  func createDeleteSection(wallet: Wallet) -> SettingsListV2Section {
    var items = [AnyHashable]()
    
    let deleteWalletTitle: TKUIListItemCell.Configuration.Title
    switch wallet.kind {
    case .watchonly:
      deleteWalletTitle = .string(TKLocales.Settings.Items.delete_watch_only)
    default:
      let walletTitle = wallet.iconWithName(
        attributes: TKTextStyle.label1.getAttributes(
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        ),
        iconColor: .Icon.primary,
        iconSide: 20
      )
      
      let delete = TKLocales.Settings.Items.delete_account
        .withTextStyle(
          .label1,
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        )
      let result = NSMutableAttributedString(attributedString: delete)
      result.append(walletTitle)
      deleteWalletTitle = .attributedString(result)
    }
    
    items.append(
      TKUIListItemCell.Configuration.createSettingsItem(
        id: .deleteAccountIdentifier,
        title: deleteWalletTitle,
        accessory: .icon(.TKUIKit.Icons.Size28.trashBin, .Icon.secondary),
        selectionClosure: {
          
        }
      )
    )

    items.append(
      TKUIListItemCell.Configuration.createSettingsItem(
        id: .logoutIdentifier,
        title: .string(TKLocales.Settings.Items.logout),
        accessory: .icon(.TKUIKit.Icons.Size28.door, .Accent.blue),
        selectionClosure: {
          
        }
      )
    )
    
    return SettingsListV2Section.items(topPadding: 16, items: items)
  }
}

private extension String {
  static let walletIdentifier = "WalletItem"
  static let securityItemIdentifier = "SecurityItem"
  static let backupItemIdentifier = "BackupItem"
  static let currencyItemIdentifier = "CurrencyItem"
  static let themeItemIdentifier = "ThemeItem"
  static let FAQItemIdentifier = "FAQItem"
  static let supportItemIdentifier = "SupportItem"
  static let tonkeeperNewsItemIdentifier = "TonkeeperNewsItem"
  static let contactUsItemIdentifier = "ContactUsItem"
  static let rateItemIdentifier = "RateItem"
  static let legalItemIdentifier = "LegalItem"
  static let deleteAccountIdentifier = "DeleteAccountItem"
  static let logoutIdentifier = "LogoutItem"
}
