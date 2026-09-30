import KeeperCore
import SwiftUI
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit
import WalletExtensions

final class SettingsListRootConfigurator: SettingsListConfigurator {
    var didTapEditWallet: ((Wallet) -> Void)?
    var didTapCurrencySettings: (() -> Void)?
    var didTapSecuritySettings: (() -> Void)?
    var didTapLegal: (() -> Void)?
    var didTapSupport: (() -> Void)?
    var didTapBackup: ((Wallet) -> Void)?
    var didTapLanguage: (() -> Void)?
    var didOpenURL: ((URL) -> Void)?
    var didShowAlert: ((
        _ title: String,
        _ description: String?,
        _ actions: [UIAlertAction]
    ) -> Void)?
    var didTapSignOutRegularWallet: ((Wallet) -> Void)?
    var didTapDeleteRegularWallet: ((Wallet) -> Void)?
    var didDeleteWallet: (() -> Void)?
    var didTapNotifications: ((Wallet) -> Void)?
    var didTapW5Wallet: ((Wallet) -> Void)?
    var didTapV4Wallet: ((Wallet) -> Void)?
    var didTapBattery: ((Wallet) -> Void)?
    var didTapConnectedApps: ((Wallet) -> Void)?
    var didTapMigration: ((Wallet) -> Void)?

    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        TKLocales.Settings.title
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    // MARK: - Dependencies

    private var wallet: Wallet
    private let walletsStore: WalletsStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let mnemonicsAccess: MnemonicAccess
    private let inAppReviewService: InAppReviewService
    private let configuration: Configuration
    private let walletDeleteController: WalletDeleteController
    private let anaylticsProvider: AnalyticsProvider
    private let walletNotificationStore: WalletNotificationStore
    private let settingsRepository: SettingsRepository

    // MARK: - Init

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        mnemonicsAccess: MnemonicAccess,
        inAppReviewService: InAppReviewService,
        configuration: Configuration,
        walletDeleteController: WalletDeleteController,
        anaylticsProvider: AnalyticsProvider,
        walletNotificationStore: WalletNotificationStore,
        settingsRepository: SettingsRepository
    ) {
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.mnemonicsAccess = mnemonicsAccess
        self.inAppReviewService = inAppReviewService
        self.configuration = configuration
        self.walletDeleteController = walletDeleteController
        self.anaylticsProvider = anaylticsProvider
        self.walletNotificationStore = walletNotificationStore
        self.settingsRepository = settingsRepository
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateWalletMetaData(wallet):
                DispatchQueue.main.async {
                    observer.wallet = wallet
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            case let .didUpdateWalletSetupSettings(wallet):
                DispatchQueue.main.async {
                    observer.wallet = wallet
                }
            case let .didUpdateWalletMultichain(wallet):
                DispatchQueue.main.async {
                    if wallet == observer.wallet {
                        observer.wallet = wallet
                    }
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            case let .didAddWallets(wallets):
                DispatchQueue.main.async {
                    guard wallets.contains(where: { observer.isWalletRelevantForMigrationUpdate($0) }) else {
                        return
                    }
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            case .didChangeActiveWallet:
                DispatchQueue.main.async {
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            case let .didDeleteWallet(wallet):
                DispatchQueue.main.async {
                    if wallet == observer.wallet {
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
        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateSearchEngine:
                DispatchQueue.main.async {
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            default: break
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
        if let migrationSection = createMigrationSection() {
            sections.append(migrationSection)
        }
        if let walletSettingsSection = createWalletSettingsSection(configuration: configuration) {
            sections.append(walletSettingsSection)
        }
        if let appSettingsSection = createAppSettingsSection() {
            sections.append(appSettingsSection)
        }
        sections.append(createSupportSection())
        sections.append(createLogoutSection())
        sections.append(createAppInformationSection())

        return SettingsListState(
            sections: sections
        )
    }

    private func createWalletEditSection() -> SettingsListSection {
        .items(SettingsListItemsSection(items: [.listItem(createWalletItem())]))
    }

    private func createMigrationSection() -> SettingsListSection? {
        guard shouldShowMigrationSection else { return nil }
        return .items(SettingsListItemsSection(items: [.listItem(createMigrationItem())]))
    }

    private func createWalletSettingsSection(configuration: Configuration) -> SettingsListSection? {
        var items = [SettingsListItemsSectionItem]()
        if let backupItem = createBackupItem() {
            items.append(.listItem(backupItem))
        }
        items.append(.listItem(createNotificationsItem()))
        items.append(.listItem(createCurrencyItem()))
        if let w5Item = createW5Item() {
            items.append(.listItem(w5Item))
        }
        if let v4Item = createV4Item() {
            items.append(.listItem(v4Item))
        }
        if
            !configuration.flag(\.batteryDisabled, network: wallet.network),
            let batteryItem = createBatteryItem(isBeta: configuration.isBatteryBeta(network: wallet.network))
        {
            items.append(.listItem(batteryItem))
        }
        items.append(.listItem(createConnectedAppsItem()))

        guard !items.isEmpty else { return nil }

        return .items(SettingsListItemsSection(items: items))
    }

    private var shouldShowMigrationSection: Bool {
        WalletMigrationVisibility.shouldShowMigrationSection(
            wallet: wallet,
            wallets: walletsStore.wallets
        )
    }

    private func isWalletRelevantForMigrationUpdate(_ wallet: Wallet) -> Bool {
        wallet == self.wallet || WalletMigrationVisibility.isLegacyTonWallet(wallet)
    }

    private func createAppSettingsSection() -> SettingsListSection? {
        var items = [SettingsListItem]()
        if let securityItem = createSecurityItem() {
            items.append(securityItem)
        }
        items.append(createThemeItem())
        items.append(createSearchItem())
        items.append(createLanguageItem())

        guard !items.isEmpty else { return nil }

        return .items(SettingsListItemsSection(items: items.map(SettingsListItemsSectionItem.listItem)))
    }

    private func createSupportSection() -> SettingsListSection {
        var items = [
            createFAQItem(),
            createSupportItem(),
            createNewsItem(),
            createContactUsItem(),
            createRateItem(),
        ]
        if let deleteItem = createDeleteWalletItem() {
            items.append(deleteItem)
        }
        items.append(createLegalItem())
        return .items(SettingsListItemsSection(items: items.map(SettingsListItemsSectionItem.listItem)))
    }

    private func createLogoutSection() -> SettingsListSection {
        .items(SettingsListItemsSection(items: [.listItem(createSignOutWalletItem())]))
    }

    private func createAppInformationSection() -> SettingsListSection {
        .appInformation(
            SettingsListAppInformation(
                appName: InfoProvider.appName(),
                version: "Version \(InfoProvider.appVersion())(\(InfoProvider.buildVersion()))"
            )
        )
    }

    private func createWalletItem() -> SettingsListItem {
        let icon: SettingsListItemIcon? = {
            let backgroundColor = TKColor.fixed(Color(uiColor: wallet.tintColor.uiColor))
            switch wallet.icon {
            case let .emoji(emoji):
                return .emoji(emoji, backgroundColor: backgroundColor)
            case let .icon(image):
                return .image(
                    SettingsListItemImageIcon(
                        image: image.swiftUIImage,
                        tintColor: .fixed(.white),
                        backgroundColor: backgroundColor
                    )
                )
            }
        }()
        // A multichain wallet spans several chains, so no single TON contract revision describes it.
        let tags: [TKTagSwiftUIViewConfig] = wallet.isMultichain
            ? []
            : wallet.listTagSwiftUIConfigurations()
        return SettingsListItem(
            id: .walletIdentifier,
            icon: icon,
            title: SettingsListItemTitle(wallet.label),
            tags: tags,
            captions: [SettingsListItemCaption(TKLocales.Settings.Items.setupWalletDescription)],
            accessory: .chevron,
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didTapEditWallet?(self.wallet)
            }
        )
    }

    private func createMigrationItem() -> SettingsListItem {
        SettingsListItem(
            id: .migrationItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.migration),
            redDotColor: settingsRepository.didOpenWalletMigration ? nil : .accentBlue,
            captions: [SettingsListItemCaption(TKLocales.Settings.Items.migrationDescription)],
            accessory: .icon(.TKUIKit.Icons.Size28.trayArrowDown, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                var settingsRepository = self.settingsRepository
                settingsRepository.didOpenWalletMigration = true
                self.didUpdateState?(self.createState())
                self.didTapMigration?(self.wallet)
            }
        )
    }

    private func createBackupItem() -> SettingsListItem? {
        guard wallet.isBackupAvailable else {
            return nil
        }

        let isBackupNotificationVisible = wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
        return SettingsListItem(
            id: .backupItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.backup),
            redDotColor: isBackupNotificationVisible ? .accentRed : nil,
            accessory: .icon(.TKUIKit.Icons.Size28.key, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didTapBackup?(wallet)
            }
        )
    }

    private func createCurrencyItem() -> SettingsListItem {
        let currency = currencyStore.getState()
        return SettingsListItem(
            id: .currencyItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.currency),
            accessory: .text(
                SettingsListItemTextAccessory(
                    text: currency.code,
                    color: .accentBlue,
                    textStyle: .label1
                )
            ),
            onTap: { [weak self] _ in
                self?.didTapCurrencySettings?()
            }
        )
    }

    private func createW5Item() -> SettingsListItem? {
        guard !wallet.isW5, !configuration.flag(\.gaslessDisabled, network: wallet.network) else { return nil }
        let isW5Added: Bool = { [walletsStore] in
            let wallets = walletsStore.wallets.filter { $0.kind == .regular || $0.kind == .signer }
            do {
                return try wallets.contains(where: { try $0.publicKey == wallet.publicKey && $0.isW5 })
            } catch {
                return false
            }
        }()
        guard !isW5Added else { return nil }
        return SettingsListItem(
            id: .walletW5ItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.walletW5),
            accessory: .icon(.TKUIKit.Icons.Size28.wallet, tintColor: .accentBlue),
            onTap: { [weak self] _ in
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
        return SettingsListItem(
            id: .walletV4ItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.walletV4R2),
            accessory: .icon(.TKUIKit.Icons.Size28.wallet, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                didTapV4Wallet?(wallet)
            }
        )
    }

    private func createSecurityItem() -> SettingsListItem? {
        let hasMnemonics = mnemonicsAccess.hasMnemonics()
        let hasRegularWallet = walletsStore.wallets.contains(where: { $0.kind == .regular })
        guard hasMnemonics, hasRegularWallet else { return nil }
        return SettingsListItem(
            id: .securityItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.security),
            accessory: .icon(.TKUIKit.Icons.Size28.lock, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                self?.didTapSecuritySettings?()
            }
        )
    }

    private func createSearchItem() -> SettingsListItem {
        let searchEngine = appSettingsStore.state.searchEngine
        return SettingsListItem(
            id: .searchItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.search),
            accessory: .text(
                SettingsListItemTextAccessory(
                    text: searchEngine.rawValue,
                    color: .accentBlue,
                    textStyle: .label1
                )
            ),
            onTap: { [weak self] view in
                guard let self, let view else { return }

                let items = SearchEngine.allCases.map { item in
                    TKPopupMenuItem(
                        title: item.rawValue,
                        value: nil,
                        description: nil,
                        icon: nil
                    ) {
                        self.appSettingsStore.setSearchEngine(item)
                    }
                }

                let selectedIndex = SearchEngine.allCases.firstIndex(of: searchEngine)
                TKPopupMenuController.show(
                    sourceView: view,
                    position: .topRight,
                    minimumWidth: 0,
                    items: items,
                    selectedIndex: selectedIndex
                )
            }
        )
    }

    private func createLanguageItem() -> SettingsListItem {
        SettingsListItem(
            id: .languageItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.language),
            accessory: .text(
                SettingsListItemTextAccessory(
                    text: TKLocales.language,
                    color: .accentBlue,
                    textStyle: .label1
                )
            ),
            onTap: { [weak self] _ in
                self?.didTapLanguage?()
            }
        )
    }

    private func createConnectedAppsItem() -> SettingsListItem {
        SettingsListItem(
            id: .connectedAppsIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.connectedApps),
            accessory: .icon(.TKUIKit.Icons.Size28.connectedApps, tintColor: .accentBlue),
            onTap: { [weak self, wallet] _ in
                self?.didTapConnectedApps?(wallet)
            }
        )
    }

    private func createThemeItem() -> SettingsListItem {
        SettingsListItem(
            id: .themeItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.theme),
            accessory: .text(
                SettingsListItemTextAccessory(
                    text: TKThemeManager.shared.theme.title,
                    color: .accentBlue,
                    textStyle: .label1
                )
            ),
            onTap: { view in
                guard let view else { return }
                let items = TKTheme.allCases.map { theme in
                    TKPopupMenuItem(
                        title: theme.title,
                        value: nil,
                        description: nil,
                        icon: nil
                    ) {
                        TKThemeManager.shared.theme = theme
                    }
                }
                let selectedIndex = TKTheme.allCases.firstIndex(of: TKThemeManager.shared.theme)
                TKPopupMenuController.show(
                    sourceView: view,
                    position: .topRight,
                    minimumWidth: 0,
                    items: items,
                    selectedIndex: selectedIndex
                )
            }
        )
    }

    func createFAQItem() -> SettingsListItem {
        SettingsListItem(
            id: .FAQItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.faq),
            accessory: .icon(.TKUIKit.Icons.Size28.question, tintColor: .accentBlue),
            onTap: { [weak self, configuration] _ in
                guard let self else { return }
                Task {
                    guard let contactUsURL = configuration
                        .faqUrl
                    else {
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
        SettingsListItem(
            id: .supportItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.support),
            accessory: .icon(.TKUIKit.Icons.Size28.telegram, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                didTapSupport?()
            }
        )
    }

    func createNewsItem() -> SettingsListItem {
        SettingsListItem(
            id: .tonkeeperNewsItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.tkNews),
            accessory: .icon(.TKUIKit.Icons.Size28.telegram, tintColor: .iconSecondary),
            onTap: { [weak self, configuration] _ in
                guard let self else { return }
                Task {
                    guard let contactUsURL = configuration
                        .tonkeeperNewsUrl
                    else {
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
        SettingsListItem(
            id: .contactUsItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.contactUs),
            accessory: .icon(.TKUIKit.Icons.Size28.messageBubble, tintColor: .iconSecondary),
            onTap: { [weak self, configuration] _ in
                guard let self else { return }
                Task {
                    guard let contactUsURL = configuration
                        .supportLink
                    else {
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
        SettingsListItem(
            id: .rateItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.rate(InfoProvider.appName())),
            accessory: .icon(.TKUIKit.Icons.Size28.star, tintColor: .iconSecondary),
            onTap: { [weak self] _ in
                self?.inAppReviewService.requestReviewManual()
            }
        )
    }

    func createLegalItem() -> SettingsListItem {
        SettingsListItem(
            id: .legalItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.legal),
            accessory: .icon(.TKUIKit.Icons.Size28.doc, tintColor: .iconSecondary),
            onTap: { [weak self] _ in
                self?.didTapLegal?()
            }
        )
    }

    func createSignOutWalletItem() -> SettingsListItem {
        let title: SettingsListItemTitle
        let action: () -> Void

        let isWatchOnly = wallet.kind == .watchonly
        if isWatchOnly {
            title = SettingsListItemTitle(TKLocales.Settings.Items.deleteWatchOnly)
        } else {
            title = createSignOutWalletTitle(wallet: wallet)
        }

        let hasSeedPhrase = wallet.kind == .regular
        if hasSeedPhrase {
            action = { [weak self] in
                guard let self else { return }
                self.didTapSignOutRegularWallet?(self.wallet)
            }
        } else {
            action = { [weak self] in
                guard let self else { return }
                let actions = [
                    UIAlertAction(title: TKLocales.Actions.delete, style: .destructive, handler: { [weak self] _ in
                        guard let self else { return }
                        Task { [self] in
                            await self.walletNotificationStore.setNotificationIsOn(false, wallet: self.wallet)
                            await self.walletDeleteController.deleteWallet(wallet: self.wallet)
                            await MainActor.run {
                                self.didDeleteWallet?()
                                self.anaylticsProvider.log(eventKey: .deleteWallet)
                            }
                        }
                    }),
                    UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel),
                ]

                self.didShowAlert?(
                    isWatchOnly ? TKLocales.Settings.Items.deleteWatchOnlyAcountAlertTitle : TKLocales.Settings.Items.deleteAcountAlertTitle,
                    nil,
                    actions
                )
            }
        }

        return SettingsListItem(
            id: .signOutIdentifier,
            title: title,
            accessory: .icon(.TKUIKit.Icons.Size28.door, tintColor: .accentBlue),
            onTap: { _ in
                action()
            }
        )
    }

    private func createDeleteWalletItem() -> SettingsListItem? {
        guard wallet.kind == .regular else { return nil }
        return SettingsListItem(
            id: .deleteAccountIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.deleteAccount),
            accessory: .icon(.TKUIKit.Icons.Size28.trashBin, tintColor: .iconSecondary),
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didTapDeleteRegularWallet?(self.wallet)
            }
        )
    }

    private func createSignOutWalletTitle(wallet: Wallet) -> SettingsListItemTitle {
        switch wallet.icon {
        case let .emoji(emoji):
            SettingsListItemTitle("\(TKLocales.Settings.Items.signOutAccount)\(emoji) \(wallet.label)")
        case let .icon(image):
            SettingsListItemTitle(parts: [
                .text(TKLocales.Settings.Items.signOutAccount),
                .icon(image.swiftUIImage),
                .text(" \(wallet.label)"),
            ])
        }
    }

    private func createNotificationsItem() -> SettingsListItem {
        SettingsListItem(
            id: .notificationsIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.notifications),
            accessory: .icon(.TKUIKit.Icons.Size28.notification, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didTapNotifications?(self.wallet)
            }
        )
    }

    private func createBatteryItem(isBeta: Bool) -> SettingsListItem? {
        guard wallet.kind == .regular else { return nil }
        var tags = [TKTagSwiftUIViewConfig]()
        if isBeta {
            tags.append(.tag(text: "BETA"))
        }
        return SettingsListItem(
            id: .batteryIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Items.battery),
            tags: tags,
            accessory: .icon(.TKUIKit.Icons.Size28.battery, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didTapBattery?(wallet)
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
    static let searchItemIdentifier = "SearchItem"
    static let languageItemIdentifier = "LanguageItem"
    static let themeItemIdentifier = "ThemeItem"
    static let FAQItemIdentifier = "FAQItem"
    static let supportItemIdentifier = "SupportItem"
    static let tonkeeperNewsItemIdentifier = "TonkeeperNewsItem"
    static let contactUsItemIdentifier = "ContactUsItem"
    static let rateItemIdentifier = "RateItem"
    static let legalItemIdentifier = "LegalItem"
    static let signOutIdentifier = "SignOutIdentifier"
    static let deleteAccountIdentifier = "DeleteAccountItem"
    static let notificationsIdentifier = "Notifications item"
    static let batteryIdentifier = "Battery item"
    static let connectedAppsIdentifier = "ConnectedAppsItem"
    static let migrationItemIdentifier = "migrationItemIdentifier"
}
