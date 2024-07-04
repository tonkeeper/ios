import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

final class SettingsRootListItemsProvider: SettingsListItemsProvider {
  var didTapEditWallet: ((Wallet) -> Void)?
  var didTapCurrency: (() -> Void)?
  var didTapTheme: (() -> Void)?
  var didTapBackup: ((Wallet) -> Void)?
  var didTapSecurity: (() -> Void)?
  var didShowAlert: ((_ title: String, _ description: String?, _ actions: [UIAlertAction]) -> Void)?
  var didTapLogout: (() -> Void)?
  var didTapDeleteAccount: (() -> Void)?
    
  private let settingsController: SettingsController
  private let urlOpener: URLOpener
  private let appStoreReviewer: AppStoreReviewer
  private let appSettings: AppSettings
  private let analyticsProvider: AnalyticsProvider
  
  init(settingsController: SettingsController,
       urlOpener: URLOpener,
       appStoreReviewer: AppStoreReviewer,
       appSettings: AppSettings,
       analyticsProvider: AnalyticsProvider) {
    self.settingsController = settingsController
    self.appStoreReviewer = appStoreReviewer
    self.urlOpener = urlOpener
    self.appSettings = appSettings
    self.analyticsProvider = analyticsProvider
    
    settingsController.didUpdateActiveWallet = { [weak self] in
      self?.didUpdateSections?()
    }
    
    settingsController.didUpdateActiveCurrency = { [weak self] in
      self?.didUpdateSections?()
    }
    
    settingsController.didDeleteWallet = { [weak self] in
      self?.didTapDeleteAccount?()
    }
    
    settingsController.didDeleteLastWallet = { [weak self] in
      self?.didTapLogout?()
    }
  }
  
  var didUpdateSections: (() -> Void)?
  
  var title: String { TKLocales.Settings.title }
  
  func getSections() async -> [SettingsListSection] {
    await setupSettingsSections()
  }
  
  func selectItem(section: SettingsListSection, index: Int) {}
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    return nil
  }
}

private extension SettingsRootListItemsProvider {
  func setupSettingsSections() async -> [SettingsListSection] {
    var sections = [SettingsListSection]()
    
    sections.append(setupWalletSection())

    var securitySectionItems = [SettingsCell.Model]()
    if settingsController.hasSecurity() {
      securitySectionItems.append(setupSecurityItem())
    }
    switch settingsController.activeWallet().kind {
    case .regular:
      securitySectionItems.append(setupBackupItem())
    default: break
    }
    
    if !securitySectionItems.isEmpty {
      sections.append(SettingsListSection(
        padding: .sectionPadding,
        items: securitySectionItems
      ))
    }
    
    await sections.append(SettingsListSection(
      padding: .sectionPadding,
      items: [
        await setupCurrencyItem(),
        setupThemeItem(),
      ]
    ))
    
    sections.append(SettingsListSection(
      padding: .sectionPadding,
      items: [
        setupSupportItem(),
        setupTonkeeperNewsItem(),
        setupContactUsItem(),
        setupRateItem(),
      ]
    ))
    
    var logoutSectionItems = [AnyHashable]()
    switch settingsController.activeWallet().kind {
    case .watchonly:
      logoutSectionItems.append(setupDeleteWatchOnlyAccount())
    default:
      logoutSectionItems.append(setupDeleteAccountItem())
    }
    logoutSectionItems.append(setupLogoutItem())
    
    sections.append(SettingsListSection(
      padding: .sectionPadding,
      items:
        logoutSectionItems
    ))
    
    return sections
  }
  
  func setupWalletSection() -> SettingsListSection {
    let wallet = settingsController.activeWallet()
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
      accessoryConfiguration: TKUIListItemAccessoryView.Configuration.none
    )
    
    let configuration = TKUIListItemCell.Configuration(
      id: "wallet",
      listItemConfiguration: listItemConfiguration,
      isHighlightable: true,
      selectionClosure: { [weak self] in
        guard let self = self else { return }
        self.didTapEditWallet?(self.settingsController.activeWallet())
      }
    )
    return SettingsListSection(
      padding: NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16),
      items: [configuration]
    )
  }
  
  func setupSecuritySection() -> SettingsSection {
    SettingsSection.settingsItems(items: [
      setupSecurityItem(),
      setupBackupItem()
    ])
  }
  
  func setupSecurityItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .securityItemTitle,
      selectionHandler: { [weak self] in
        self?.didTapSecurity?()
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .securityItemTitle,
        icon: .TKUIKit.Icons.Size28.key,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupBackupItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .backupItemTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        self.didTapBackup?(self.settingsController.activeWallet())
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .backupItemTitle,
        icon: .TKUIKit.Icons.Size28.lock,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupCurrencyItem() async -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .currencyItemTitle,
      selectionHandler: { [weak self] in
        self?.didTapCurrency?()
      },
      cellContentModel: await SettingsCellContentView.Model(
        title: .currencyItemTitle,
        value: settingsController.activeCurrency().code
      )
    )
  }
  
  func setupThemeItem() async -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .themeItemTitle,
      selectionHandler: { [weak self] in
        self?.didTapTheme?()
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .themeItemTitle,
        value: TKThemeManager.shared.theme.title
      )
    )
  }
  
  func setupSocialLinksSection() -> SettingsSection {
    SettingsSection.settingsItems(items: [
      setupSupportItem(),
      setupTonkeeperNewsItem(),
      setupContactUsItem(),
      setupRateItem(),
      setupDeleteAccountItem()
    ])
  }
  
  func setupSupportItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .logoutItemTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        Task {
          guard let url = try await self.settingsController.supportURL else { return }
          await MainActor.run {
            self.urlOpener.open(url: url)
          }
        }
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .supportTitle,
        icon: .TKUIKit.Icons.Size28.telegram,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupTonkeeperNewsItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .tonkeeperNewsTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        Task {
          guard let url = try await self.settingsController.tonkeeperNewsURL else { return }
          await MainActor.run {
            self.urlOpener.open(url: url)
          }
        }
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .tonkeeperNewsTitle,
        icon: .TKUIKit.Icons.Size28.telegram,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupContactUsItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .contactUsTitle,
      selectionHandler: {  [weak self] in
        guard let self = self else { return }
        Task {
          guard let url = try await self.settingsController.contactUsURL else { return }
          await MainActor.run {
            self.urlOpener.open(url: url)
          }
        }
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .contactUsTitle,
        icon: .TKUIKit.Icons.Size28.messageBubble,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupRateItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .rateTonkeeperXTitle,
      selectionHandler: { [weak self] in
        self?.appStoreReviewer.requestReview()
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .rateTonkeeperXTitle,
        icon: .TKUIKit.Icons.Size28.star,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupDeleteAccountItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .deleteItemTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        
        let actions = [
          UIAlertAction(title: .deleteDeleteButtonTitle, style: .destructive, handler: { [weak self] _ in
            do {
              self?.analyticsProvider.logEvent(eventKey: .deleteWallet)
              try self?.settingsController.deleteAccount()
              self?.didTapDeleteAccount?()
            } catch {}
          }),
          UIAlertAction(title: .deleteCancelButtonTitle, style: .cancel)
        ]
        
        self.didShowAlert?(.deleteTitle, .deleteDescription, actions)
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .deleteItemTitle,
        icon: .TKUIKit.Icons.Size28.trashBin,
        tintColor: .Icon.secondary
      )
    )
  }
  
  func setupLogoutSection() -> SettingsSection {
    SettingsSection.settingsItems(items: [
      setupLogoutItem()
    ])
  }
  
  func setupDeleteWatchOnlyAccount() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .deleteWatchItemTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        
        let actions = [
          UIAlertAction(title: .deleteWatchTitle, style: .destructive, handler: { [weak self] _ in
            do {
              self?.analyticsProvider.logEvent(eventKey: .deleteWallet)
              try self?.settingsController.deleteAccount()
              self?.didTapDeleteAccount?()
            } catch {}
          }),
          UIAlertAction(title: .deleteWatchCancelButtonTitle, style: .cancel)
        ]
        
        self.didShowAlert?(.deleteWatchDeleteButtonTitle, .deleteDescription, actions)
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .deleteWatchItemTitle,
        icon: .TKUIKit.Icons.Size28.trashBin,
        tintColor: .Accent.blue
      )
    )
  }
  
  func setupLogoutItem() -> SettingsCell.Model {
    SettingsCell.Model(
      identifier: .logoutItemTitle,
      selectionHandler: { [weak self] in
        guard let self = self else { return }
        
        let actions = [
          UIAlertAction(title: .deleteDeleteButtonTitle, style: .destructive, handler: { [weak self] _ in
            self?.analyticsProvider.logEvent(eventKey: .resetWallet)
            self?.didTapLogout?()
          }),
          UIAlertAction(title: .deleteCancelButtonTitle, style: .cancel)
        ]
        
        self.didShowAlert?(.logoutTitle, .logoutDescription, actions)
      },
      cellContentModel: SettingsCellContentView.Model(
        title: .logoutItemTitle,
        icon: .TKUIKit.Icons.Size28.door,
        tintColor: .Accent.blue
      )
    )
  }
}

private extension String {
  static let securityItemTitle = TKLocales.Settings.Items.security
  
  static let backupItemTitle = TKLocales.Settings.Items.backup
  
  static let currencyItemTitle = TKLocales.Settings.Items.currency
  static let themeItemTitle = TKLocales.Settings.Items.theme
  
  static let logoutItemTitle = TKLocales.Settings.Items.logout
  static let logoutTitle = TKLocales.Settings.Logout.title
  static let logoutDescription = TKLocales.Settings.Logout.description
  static let logoutCancelButtonTitle = TKLocales.Actions.cancel
  static let logoutLogoutButtonTitle = TKLocales.Settings.Items.logout
  
  static let supportTitle = TKLocales.Settings.Items.support
  static let tonkeeperNewsTitle = TKLocales.Settings.Items.tk_news
  static let contactUsTitle = TKLocales.Settings.Items.contact_us
  static let rateTonkeeperXTitle = TKLocales.Settings.Items.rate
  static let legalTitle = TKLocales.Settings.Items.legal
  
  static let deleteItemTitle = TKLocales.Settings.Items.delete_account
  static let deleteTitle = "Are you sure you want to delete your account?"
  static let deleteDescription = "This action will delete your account and all data from this application."
  static let deleteDeleteButtonTitle = "Delete account and data"
  static let deleteCancelButtonTitle = TKLocales.Actions.cancel
  
  static let deleteWatchItemTitle = "Delete Watch Account"
  static let deleteWatchTitle = "Are you sure you want to delete Watch account?"
  static let deleteWatchDeleteButtonTitle = TKLocales.Actions.delete
  static let deleteWatchCancelButtonTitle = TKLocales.Actions.cancel
}

private extension NSDirectionalEdgeInsets {
  static let sectionPadding = NSDirectionalEdgeInsets(
    top: 16,
    leading: 16,
    bottom: 16,
    trailing: 16
  )
}
