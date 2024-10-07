import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListRootConfigurator: SettingsListConfigurator {

  var didRequirePasscode: (() async -> String?)?
  var didTapEditWallet: ((Wallet) -> Void)?
  var didTapCurrencySettings: (() -> Void)?
  var didTapSecuritySettings: (() -> Void)?
  var didTapLegal: (() -> Void)?
  var didTapBackup: (() -> Void)?
  var didOpenURL: ((URL) -> Void)?
  var didShowAlert: ((_ title: String,
                      _ description: String?,
                      _ actions: [UIAlertAction]) -> Void)?
  var didTapSignOutRegularWallet: ((Wallet) -> Void)?
  var didTapDeleteRegularWallet: ((Wallet) -> Void)?
  var didTapLogout: (() -> Void)?
  var didDeleteWallet: (() -> Void)?
  var didTapPurchases: ((Wallet) -> Void)?
  var didTapNotifications: ((Wallet) -> Void)?
  var didTapW5Wallet: ((Wallet) -> Void)?
  var didTapV4Wallet: ((Wallet) -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  
  var title: String { TKLocales.Settings.title }
  var isSelectable: Bool { false }
  
  func getInitialState() -> SettingsListState {
    createState()
  }

  // MARK: - Dependencies
  
  private var wallet: Wallet
  private let walletsStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let mnemonicsRepository: MnemonicsRepository
  private let appStoreReviewer: AppStoreReviewer
  private let configurationStore: ConfigurationStore
  private let walletNFTStore: WalletNFTStore
  private let walletDeleteController: WalletDeleteController
  private let anaylticsProvider: AnalyticsProvider
  
  // MARK: - Init
  
  init(wallet: Wallet,
       walletsStore: WalletsStore,
       currencyStore: CurrencyStore,
       mnemonicsRepository: MnemonicsRepository,
       appStoreReviewer: AppStoreReviewer,
       configurationStore: ConfigurationStore,
       walletNFTStore: WalletNFTStore,
       walletDeleteController: WalletDeleteController,
       anaylticsProvider: AnalyticsProvider) {
    self.wallet = wallet
    self.walletsStore = walletsStore
    self.currencyStore = currencyStore
    self.mnemonicsRepository = mnemonicsRepository
    self.appStoreReviewer = appStoreReviewer
    self.configurationStore = configurationStore
    self.walletNFTStore = walletNFTStore
    self.walletDeleteController = walletDeleteController
    self.anaylticsProvider = anaylticsProvider
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateWalletMetaData(let wallet):
        DispatchQueue.main.async {
          observer.wallet = wallet
          let state = observer.createState()
          observer.didUpdateState?(state)
        }
      case .didUpdateWalletSetupSettings(let wallet):
        DispatchQueue.main.async {
          observer.wallet = wallet
        }
      case .didDeleteWallet(let wallet):
        DispatchQueue.main.async {
          if wallet == self.wallet {
            observer.didDeleteWallet?()
          } else {
            let state = observer.createState()
            observer.didUpdateState?(state)
          }
        }
      default: break
      }
    }
    currencyStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateCurrency:
        DispatchQueue.main.async {
          let state = observer.createState()
          observer.didUpdateState?(state)
        }
      }
    }
    walletNFTStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateNFTs(let wallet):
        DispatchQueue.main.async {
          guard wallet == self.wallet else { return }
          let state = observer.createState()
          observer.didUpdateState?(state)
        }
      }
    }
    TKThemeManager.shared.addEventObserver(self) { observer, _ in
      DispatchQueue.main.async {
        let state = observer.createState()
        observer.didUpdateState?(state)
      }
    }
  }
  
  private func createState() -> SettingsListState {
    var sections = [SettingsListSection]()
    
    sections.append(createWalletEditSection())
    if let walletSettingsSection = createWalletSettingsSection() {
      sections.append(walletSettingsSection)
    }
    if let appSettingsSection = createAppSettingsSection() {
      sections.append(appSettingsSection)
    }
    sections.append(createSupportSection())
    sections.append(createLogoutSection())
    sections.append(createAppInformationSection())
    
    let state = SettingsListState(
      sections: sections
    )
    return state
  }
  
  private func createWalletEditSection() -> SettingsListSection {
    return SettingsListSection.listItems(
      SettingsListItemsSection(
        items: [createWalletItem()],
        topPadding: 0,
        bottomPadding: 16
      )
    )
  }
  
  private func createWalletSettingsSection() -> SettingsListSection? {
    var items = [AnyHashable]()
    if let backupItem = createBackupItem() {
      items.append(backupItem)
    }
    if let purchasesManagementItem = createPurchasesManagementItem() {
      items.append(purchasesManagementItem)
    }
    items.append(createNotificationsItem())
    items.append(createCurrencyItem())
    if let w5Item = createW5Item() {
      items.append(w5Item)
    }
    if let v4Item = createV4Item() {
      items.append(v4Item)
    }
    guard !items.isEmpty else { return nil }
    return SettingsListSection.listItems(
      SettingsListItemsSection(
        items: items,
        topPadding: 16,
        bottomPadding: 16
      )
    )
  }
  
  private func createAppSettingsSection() -> SettingsListSection? {
    var items = [SettingsListItem]()
    if let securityItem = createSecurityItem() {
      items.append(securityItem)
    }
    items.append(createThemeItem())
    guard !items.isEmpty else { return nil }
    return SettingsListSection.listItems(
      SettingsListItemsSection(
        items: items,
        topPadding: 16,
        bottomPadding: 16
      )
    )
  }
  
  private func createSupportSection() -> SettingsListSection {
    var items = [
      createFAQItem(),
      createSupportItem(),
      createNewsItem(),
      createContactUsItem(),
      createRateItem()
    ]
    if let deleteItem = createDeleteWalletItem() {
      items.append(deleteItem)
    }
    items.append(createLegalItem())
    return SettingsListSection.listItems(
      SettingsListItemsSection(
        items: items,
        topPadding: 16,
        bottomPadding: 16
      )
    )
  }
  
  private func createLogoutSection() -> SettingsListSection {
    let items = [
      createSignOutWalletItem()
    ]
    return SettingsListSection.listItems(
      SettingsListItemsSection(
        items: items,
        topPadding: 16,
        bottomPadding: 0
      )
    )
  }
  
  private func createAppInformationSection() -> SettingsListSection {
    let configuration = SettingsAppInformationCell.Configuration(
      appName: InfoProvider.appName(),
      version: "Version \(InfoProvider.appVersion())"
    )
    return SettingsListSection.appInformation(configuration)
  }
  
  private func createWalletItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: wallet.listItemIconViewConfiguration,
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: wallet.label,
                                                                    tags: wallet.listTagConfigurations()),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: TKLocales.Settings.Items.setupWalletDescription,
                                             color: .Text.secondary,
                                             textStyle: .body2)
          ]
        )
      ))
    return SettingsListItem(id: .walletIdentifier,
                            cellConfiguration: cellConfiguration,
                            accessory: .chevron) { [weak self] _ in
      guard let self else { return }
      self.didTapEditWallet?(self.wallet)
    }
  }
  
  private func createPurchasesManagementItem() -> SettingsListItem? {
    guard let nfts = walletNFTStore.getState()[wallet] else { return nil }
    guard !nfts.isEmpty else { return nil }
    
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.purchases)
        )))
    
    return SettingsListItem(id: .purchasesIdentifier,
                            cellConfiguration: cellConfiguration,
                            accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.purchase, tintColor: .Accent.blue)),
                            onSelection: { [weak self] _ in
      guard let self else { return }
      self.didTapPurchases?(self.wallet)
    })
  }
  
  private func createBackupItem() -> SettingsListItem? {
    guard wallet.isBackupAvailable else {
      return nil
    }

    let title = TKLocales.Settings.Items.backup
      .withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    let resultAttributedString = NSMutableAttributedString(attributedString: title)

    let isBackupNotificationVisible = wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
    if isBackupNotificationVisible {
      resultAttributedString.append(" •".withTextStyle(.h2, color: .Accent.red))
    }
    let titleViewConfiguration = TKListItemTitleView.Configuration(title: resultAttributedString, numberOfLines: 1)
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: titleViewConfiguration
        )
      )
    )
    
    return SettingsListItem(
      id: .backupItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.lock, tintColor: .Accent.blue)),
      onSelection: { [weak self] _ in
        self?.didTapBackup?()
      }
    )
  }
  
  private func createCurrencyItem() -> SettingsListItem {
    let currency = currencyStore.getState()
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.currency)
        )))
    return SettingsListItem(
      id: .currencyItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .text(
        TKListItemTextAccessoryView.Configuration(
          text: currency.code,
          color: .Accent.blue,
          textStyle: .label1
        )
      ),
      onSelection: {
        [weak self] _ in
        self?.didTapCurrencySettings?()
      }
    )
  }
  
  private func createW5Item() -> SettingsListItem? {
    guard !wallet.isW5 else { return nil }
    let isW5Added: Bool = { [walletsStore] in
      let wallets = walletsStore.wallets.filter { $0.kind == .regular || $0.kind == .signer }
      do {
        return try wallets.contains(where: { try $0.publicKey == wallet.publicKey && $0.isW5 })
      } catch {
        return false
      }
    }()
    guard !isW5Added else { return nil }
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.walletW5)
        )))
    return SettingsListItem(
      id: .walletW5ItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.wallet, tintColor: .Accent.blue)),
      onSelection: {
        [weak self] _ in
        guard let self else { return }
        didTapW5Wallet?(wallet)
      }
    )
  }
  
  private func createV4Item() -> SettingsListItem? {
    guard wallet.isW5 else { return nil }
    let isV4R2Added: Bool = { [walletsStore] in
      let wallets = walletsStore.wallets.filter { $0.kind == .regular || $0.kind == .signer }
      do {
        return try wallets.contains(where: { try $0.publicKey == wallet.publicKey && $0.isV4R2 })
      } catch {
        return false
      }
    }()
    guard !isV4R2Added else { return nil }
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.walletV4R2)
        )))
    return SettingsListItem(
      id: .walletV4ItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.wallet, tintColor: .Accent.blue)),
      onSelection: {
        [weak self] _ in
        guard let self else { return }
        didTapV4Wallet?(wallet)
      }
    )
  }
  
  private func createSecurityItem() -> SettingsListItem? {
    let hasMnemonics = mnemonicsRepository.hasMnemonics()
    let hasRegularWallet = walletsStore.wallets.contains(where: { $0.kind == .regular })
    guard hasMnemonics && hasRegularWallet else { return nil }
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.security)
        )))
    return SettingsListItem(
      id: .securityItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.key, tintColor: .Accent.blue)),
      onSelection: {
        [weak self] _ in
        self?.didTapSecuritySettings?()
      }
    )
  }
  
  private func createThemeItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.theme)
        )))
    return SettingsListItem(
      id: .themeItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .text(
        TKListItemTextAccessoryView.Configuration(
          text: TKThemeManager.shared.theme.title,
          color: .Accent.blue,
          textStyle: .label1
        )
      ),
      onSelection: { view in
        guard let view else { return }
        let items = TKTheme.allCases.map { theme in
          TKPopupMenuItem(title: theme.title,
                          value: nil,
                          description: nil,
                          icon: nil) {
            TKThemeManager.shared.theme = theme
          }
        }
        let selectedIndex = TKTheme.allCases.firstIndex(of: TKThemeManager.shared.theme)
        TKPopupMenuController.show(
          sourceView: view,
          position: .topRight,
          width: 0,
          items: items,
          selectedIndex: selectedIndex)
      }
    )
  }
  
  func createFAQItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.faq)
        )))
    return SettingsListItem(
      id: .FAQItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.question, tintColor: .Accent.blue)),
      onSelection: {
        [weak self, configurationStore] _ in
        guard let self else { return }
        Task {
          guard let contactUsURL = await configurationStore
            .getConfiguration()
            .faqUrl else {
            return
          }
          await MainActor.run {
            self.didOpenURL?(contactUsURL)
          }
        }
      }
    )
  }
  
  func createSupportItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.support)
        )))
    return SettingsListItem(
      id: .supportItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.telegram, tintColor: .Accent.blue)),
      onSelection: {
        [weak self, configurationStore] _ in
        guard let self else { return }
        Task {
          guard let contactUsURL = await configurationStore
            .getConfiguration()
            .directSupportUrl else {
            return
          }
          await MainActor.run {
            self.didOpenURL?(contactUsURL)
          }
        }
      }
    )
  }
  
  func createNewsItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.tkNews)
        )))
    return SettingsListItem(
      id: .tonkeeperNewsItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.telegram, tintColor: .Icon.secondary)),
      onSelection: {
        [weak self, configurationStore] _ in
        guard let self else { return }
        Task {
          guard let contactUsURL = await configurationStore
            .getConfiguration()
            .tonkeeperNewsUrl else {
            return
          }
          await MainActor.run {
            self.didOpenURL?(contactUsURL)
          }
        }
      }
    )
  }
  
  func createContactUsItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.contactUs)
        )))
    return SettingsListItem(
      id: .contactUsItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.messageBubble, tintColor: .Icon.secondary)),
      onSelection: {
        [weak self, configurationStore] _ in
        guard let self else { return }
        Task {
          guard let contactUsURL = await configurationStore
            .getConfiguration()
            .supportLink else {
            return
          }
          await MainActor.run {
            self.didOpenURL?(contactUsURL)
          }
        }
      }
    )
  }
  
  func createRateItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.rate(InfoProvider.appName()))
        )))
    return SettingsListItem(
      id: .rateItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.star, tintColor: .Icon.secondary)),
      onSelection: {
        [weak self] _ in
        self?.appStoreReviewer.requestReview()
      }
    )
  }
  
  func createLegalItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.legal)
        )))
    return SettingsListItem(
      id: .legalItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.doc, tintColor: .Icon.secondary)),
      onSelection: {
        [weak self] _ in
        self?.didTapLegal?()
      }
    )
  }
  
  func createSignOutWalletItem() -> SettingsListItem {
    let title: NSAttributedString
    let action: () -> Void
    
    let isWatchOnly = wallet.kind == .watchonly
    if isWatchOnly {
      title = TKLocales.Settings.Items.deleteWatchOnly.withTextStyle(
        .label1,
        color: .Text.primary
      )
    } else {
      title = createSignOutWalletNameTitle(wallet: wallet)
    }
    
    let hasSeedPhrase = wallet.kind == .regular
    if hasSeedPhrase {
      action = { [weak self] in
        guard let self else { return }
        self.didTapSignOutRegularWallet?(self.wallet)
      }
    } else {
      action = {
        let actions = [
          UIAlertAction(title: TKLocales.Actions.delete, style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            Task {
              await self.walletDeleteController.deleteWallet(wallet: self.wallet)
              await MainActor.run {
                self.didDeleteWallet?()
                self.anaylticsProvider.logEvent(eventKey: .deleteWallet)
              }
            }
          }),
          UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel)
        ]
        
        self.didShowAlert?(
          isWatchOnly ? TKLocales.Settings.Items.deleteWatchOnlyAcountAlertTitle : TKLocales.Settings.Items.deleteAcountAlertTitle,
          nil,
          actions
        )
      }
    }

    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title, numberOfLines: 1)
        )))
    return SettingsListItem(
      id: .deleteAccountIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.door,
                                                                 tintColor: .Accent.blue)),
      onSelection: { _ in
        action()
      }
    )
  }
  
  private func createDeleteWalletItem() -> SettingsListItem? {
    guard wallet.kind == .regular else { return nil }
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: TKLocales.Settings.Items.deleteAccount.withTextStyle(
              .label1,
              color: .Text.primary
            ),
            numberOfLines: 1
          )
        )
      )
    )
    return SettingsListItem(
      id: .deleteAccountIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.trashBin,
                                                                 tintColor: .Icon.secondary)),
      onSelection: { [weak self] _ in
        guard let self else { return }
        self.didTapDeleteRegularWallet?(self.wallet)
      }
    )
  }
  
  private func createLogoutItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.logout)
        )))
    return SettingsListItem(
      id: .logoutIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.door,
                                                                 tintColor: .Accent.blue)),
      onSelection: {
        [weak self] _ in
        let actions = [
          UIAlertAction(title: TKLocales.Settings.Items.logout, style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            Task {
              await self.walletDeleteController.deleteAll()
              await MainActor.run {
                self.anaylticsProvider.logEvent(eventKey: .resetWallet)
              }
            }
          }),
          UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel)
        ]
        
        self?.didShowAlert?(TKLocales.Settings.Logout.title,
                            TKLocales.Settings.Logout.description,
                            actions)

      }
    )
  }
  
  private func createSignOutWalletNameTitle(wallet: Wallet) -> NSAttributedString {
    let walletName = wallet.iconWithName(
      attributes: TKTextStyle.label1.getAttributes(
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ),
      iconColor: .Icon.primary,
      iconSide: 20
    )
    
    let delete = TKLocales.Settings.Items.signOutAccount
      .withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    let result = NSMutableAttributedString(attributedString: delete)
    result.append(walletName)
    return result
  }
  
  private func createNotificationsItem() -> AnyHashable {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Items.notifications)
        )))
    return SettingsListItem(
      id: .notificationsIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.notification,
                                                                 tintColor: .Accent.blue)),
      onSelection: {
        [weak self] _ in
        guard let self else { return }
        self.didTapNotifications?(self.wallet)
      }
    )
  }
}

private extension String {
  static let walletIdentifier = "WalletItem"
  static let securityItemIdentifier = "SecurityItem"
  static let backupItemIdentifier = "BackupItem"
  static let currencyItemIdentifier = "CurrencyItem"
  static let walletW5ItemIdentifier = "walletW5ItemIdentifier"
  static let walletV4ItemIdentifier = "walletV4ItemIdentifier"
  static let themeItemIdentifier = "ThemeItem"
  static let FAQItemIdentifier = "FAQItem"
  static let supportItemIdentifier = "SupportItem"
  static let tonkeeperNewsItemIdentifier = "TonkeeperNewsItem"
  static let contactUsItemIdentifier = "ContactUsItem"
  static let rateItemIdentifier = "RateItem"
  static let legalItemIdentifier = "LegalItem"
  static let deleteAccountIdentifier = "DeleteAccountItem"
  static let logoutIdentifier = "LogoutItem"
  static let purchasesIdentifier = "Purhases item"
  static let notificationsIdentifier = "Notifications item"
}
