import KeeperCore
import Stories
import TKAppInfo
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import UIKit
import WebKit

final class SettingsListDevMenuConfigurator: SettingsListConfigurator {
    var didSelectRNSeedPhrasesRecovery: (() -> Void)?
    var didSelectSeedPhrasesRecovery: (() -> Void)?
    var didSelectExportLogs: (() -> Void)?
    var didSelectImportTestnetWallet: (() -> Void)?
    var didSelectFeatureFlags: (() -> Void)?
    var didSelectTooltips: (() -> Void)?
    var didSelectDesignSystem: (() -> Void)?
    var didSelectToastTesting: (() -> Void)?
    var didSelectMysteryRaffle: (() -> Void)?

    var didSelectStoreCountryCode: ((_ completion: @escaping () -> Void) -> Void)?
    var didSelectDeviceCountryCode: ((_ completion: @escaping () -> Void) -> Void)?
    var didSelectBuildVersion: ((_ completion: @escaping () -> Void) -> Void)?

    // MARK: - SettingsListConfigurator

    var title: String {
        "Dev Menu"
    }

    var didUpdateState: ((SettingsListState) -> Void)?

    func getInitialState() -> SettingsListState {
        let state = createState()

        Task {
            storeCountryCode = await appInfoProvider.storeCountryCode
        }

        return state
    }

    private var storeCountryCode: String? {
        didSet {
            let state = createState()
            didUpdateState?(state)
        }
    }

    private var deviceCountryCode: String? {
        didSet {
            let state = createState()
            didUpdateState?(state)
        }
    }

    private let uniqueIdProvider: UniqueIdProvider
    private let storiesService: StoriesService
    private let homeBannersStore: HomeBannersStore
    private let mysteryRaffleTradeBannerDismissStore: MysteryRaffleTradeBannerDismissStore
    private let appInfoProvider: KeeperCore.AppInfoProvider
    private let featureFlags: TKFeatureFlags
    private let tkAppSettings: TKAppSettings

    init(
        uniqueIdProvider: UniqueIdProvider,
        storiesService: StoriesService,
        homeBannersStore: HomeBannersStore,
        mysteryRaffleTradeBannerDismissStore: MysteryRaffleTradeBannerDismissStore = UserDefaultsMysteryRaffleTradeBannerDismissStore(),
        appInfoProvider: KeeperCore.AppInfoProvider,
        featureFlags: TKFeatureFlags,
        tkAppSettings: TKAppSettings
    ) {
        self.uniqueIdProvider = uniqueIdProvider
        self.storiesService = storiesService
        self.homeBannersStore = homeBannersStore
        self.mysteryRaffleTradeBannerDismissStore = mysteryRaffleTradeBannerDismissStore
        self.appInfoProvider = appInfoProvider
        self.featureFlags = featureFlags
        self.tkAppSettings = tkAppSettings
    }

    private func createState() -> SettingsListState {
        var sections = [SettingsListSection]()

        sections.append(createCacheSection())
        sections.append(createLogsSection())
        if let seedPhraseRecoverySection = createSeedPhraseRecoverySection() {
            sections.append(seedPhraseRecoverySection)
        }

        sections.append(createWalletsSection())
        sections.append(createConfirmationSection())

        if let regionSection = createDevOverridesSection() {
            sections.append(createDesignSystemSection())
            sections.append(createMysteryRaffleSection())
            sections.append(regionSection)
        }

        return SettingsListState(
            sections: sections
        )
    }

    private func createSeedPhraseRecoverySection() -> SettingsListSection? {
        guard !UIApplication.shared.isAppStoreEnvironment else { return nil }
        let items = [
            createRNSeedPhrasesItem(),
            createSeedPhraseRecoveryItem(),
        ]
        return .items(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem)
        ))
    }

    private func createCacheSection() -> SettingsListSection {
        let items = [
            createResetWatchedStories(),
            createResetDismissedBanners(),
        ]
        return .items(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem)
        ))
    }

    private func createLogsSection() -> SettingsListSection {
        let items = [
            createExportLogsItem(),
            createFirebaseInstallationIDItem(),
            createFirebaseUserIDItem(),
            createBuildVersionItem(),
        ]
        return .items(
            SettingsListItemsSection(
                items: items.map(SettingsListItemsSectionItem.listItem),
                header: SettingsListSectionHeader(title: "Logs")
            )
        )
    }

    private func createRNSeedPhrasesItem() -> SettingsListItem {
        SettingsListItem(
            id: .version4SeedPhrasesIdentifier,
            title: SettingsListItemTitle("Pre 5.0.0 seed phrases recovery"),
            onTap: { [weak self] _ in
                self?.didSelectRNSeedPhrasesRecovery?()
            }
        )
    }

    private func createSeedPhraseRecoveryItem() -> SettingsListItem {
        SettingsListItem(
            id: .version5SeedPhrasesIdentifier,
            title: SettingsListItemTitle("5 version seed phrases recovery"),
            onTap: { [weak self] _ in
                self?.didSelectSeedPhrasesRecovery?()
            }
        )
    }

    private func createResetWatchedStories() -> SettingsListItem {
        SettingsListItem(
            id: .resetWatchedStoriesIdentifier,
            title: SettingsListItemTitle("Reset watched stories"),
            onTap: { [weak self] _ in
                self?.storiesService.resetShownStories()
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Reseted"))
            }
        )
    }

    private func createResetDismissedBanners() -> SettingsListItem {
        SettingsListItem(
            id: .resetDismissedBannersIdentifier,
            title: SettingsListItemTitle("Reset dismissed banners"),
            onTap: { [weak self] _ in
                self?.homeBannersStore.resetDismissedBanners()
                self?.mysteryRaffleTradeBannerDismissStore.resetDismissedBanners()
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Reseted"))
            }
        )
    }

    private func createExportLogsItem() -> SettingsListItem {
        SettingsListItem(
            id: .exportLogsIdentifier,
            title: SettingsListItemTitle("Export logs"),
            onTap: { [weak self] _ in
                self?.didSelectExportLogs?()
            }
        )
    }

    private func createFirebaseInstallationIDItem() -> SettingsListItem {
        SettingsListItem(
            id: .firebaseInstallationIDIdentifier,
            title: SettingsListItemTitle("Firebase installation ID"),
            onTap: { _ in
                Task { @MainActor in
                    guard let id = await FirebaseInstallationsProvider().getInstallationID() else {
                        ToastPresenter.showToast(configuration: .defaultConfiguration(text: "No installation ID"))
                        return
                    }
                    Pasteboard.copy(value: id)
                }
            }
        )
    }

    private func createFirebaseUserIDItem() -> SettingsListItem {
        SettingsListItem(
            id: .firebaseUserIDIdentifier,
            title: SettingsListItemTitle("Firebase user ID"),
            onTap: { [weak self] _ in
                guard let self else { return }
                Pasteboard.copy(value: uniqueIdProvider.uniqueDeviceId.uuidString)
            }
        )
    }

    private func createBuildVersionItem() -> SettingsListItem {
        SettingsListItem(
            id: .buildVersionItemIdentifier,
            title: SettingsListItemTitle("Metrics tag"),
            accessory: .text(
                SettingsListItemTextAccessory(text: appInfoProvider.version)
            ),
            onTap: { [weak self] _ in
                self?.didSelectBuildVersion? {
                    guard let self else { return }
                    self.didUpdateState?(self.createState())
                }
            }
        )
    }

    private func createLoggingSeverityItem() -> SettingsListItem {
        let selectedValue = Log.configuration.minimumSeverity
        let applyValue: (LogSeverity) -> Void = { [weak self] value in
            TKAppPreferences.minimumLogSeverityRawValue = value.rawValue
            guard let self else { return }
            Log.configure()
            let state = self.createState()
            self.didUpdateState?(state)
        }

        let options = [LogSeverity.debug, .info, .warning, .error].map { severity in
            SettingsListItemMenuOption(
                title: severity.displayText.lowercased(),
                isSelected: selectedValue == severity,
                action: { applyValue(severity) }
            )
        }

        return SettingsListItem(
            id: .loggingSeverityItemIdentifier,
            title: SettingsListItemTitle("Minimum severity"),
            accessory: .menu(
                SettingsListItemMenuAccessory(
                    label: SettingsListItemTextAccessory(text: selectedValue.displayText),
                    options: options
                )
            )
        )
    }

    private func createWalletsSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createImportTestnetWalletItem()),
                ],
                header: SettingsListSectionHeader(title: "Wallets")
            )
        )
    }

    private func createFeatureFlagsItem() -> SettingsListItem {
        SettingsListItem(
            id: .featureFlagsItemIdentifier,
            title: SettingsListItemTitle("Feature Flags"),
            accessory: .chevron,
            onTap: { [weak self] _ in
                self?.didSelectFeatureFlags?()
            }
        )
    }

    private func createDesignSystemItem() -> SettingsListItem {
        SettingsListItem(
            id: .designSystemItemIdentifier,
            title: SettingsListItemTitle("Design System"),
            accessory: .chevron,
            onTap: { [weak self] _ in
                self?.didSelectDesignSystem?()
            }
        )
    }

    private func createToastTestingItem() -> SettingsListItem {
        SettingsListItem(
            id: .toastTestingItemIdentifier,
            title: SettingsListItemTitle("Toast Testing"),
            accessory: .chevron,
            onTap: { [weak self] _ in
                self?.didSelectToastTesting?()
            }
        )
    }

    private func createTooltipsItem() -> SettingsListItem {
        SettingsListItem(
            id: .tooltipsItemIdentifier,
            title: SettingsListItemTitle("Tooltips"),
            accessory: .chevron,
            onTap: { [weak self] _ in
                self?.didSelectTooltips?()
            }
        )
    }

    /// The only way into testnet: the option was pulled out of the add-wallet picker because
    /// users kept importing their seed phrase there and treating the testnet address as their own.
    private func createImportTestnetWalletItem() -> SettingsListItem {
        SettingsListItem(
            id: .importTestnetWalletItemIdentifier,
            title: SettingsListItemTitle("Import Testnet Wallet"),
            accessory: .chevron,
            onTap: { [weak self] _ in
                self?.didSelectImportTestnetWallet?()
            }
        )
    }

    private func createConfirmationSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [.listItem(createConfirmationSliderItem())],
                header: SettingsListSectionHeader(title: "Confirmation")
            )
        )
    }

    private func createDesignSystemSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createDesignSystemItem()),
                    .listItem(createToastTestingItem()),
                ],
                header: SettingsListSectionHeader(title: "Design System")
            )
        )
    }

    private func createConfirmationSliderItem() -> SettingsListItem {
        let action: (Bool) -> Void = { isOn in
            self.tkAppSettings.isConfirmButtonInsteadSlider = !isOn
        }

        return createSwitchItem(
            title: "Slider",
            id: .confirmationSliderItemIdentifier,
            isOn: !tkAppSettings.isConfirmButtonInsteadSlider,
            action: action
        )
    }

    /// Single entry into the consolidated Mystery Raffle design-review + QA screen
    /// (banner, entry point, every modal state, `_debug_now`, `pick-winners`, stories).
    private func createMysteryRaffleSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(
                        SettingsListItem(
                            id: .mysteryRaffleItemIdentifier,
                            title: SettingsListItemTitle("Design review & QA hooks"),
                            accessory: .chevron,
                            onTap: { [weak self] _ in
                                self?.didSelectMysteryRaffle?()
                            }
                        )
                    ),
                ],
                header: SettingsListSectionHeader(title: "Mystery Raffle")
            )
        )
    }

    private func createDevOverridesSection() -> SettingsListSection? {
        guard !UIApplication.shared.isAppStoreEnvironment else { return nil }

        return .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createShowTouchesItem()),
                    .listItem(createStoreCountryCodeItem()),
                    .listItem(createDeviceCountryCodeItem()),
                    .listItem(sendStatsImmediatelyItem()),
                    .listItem(createLoggingSeverityItem()),
                    .listItem(createFeatureFlagsItem()),
                    .listItem(createTooltipsItem()),
                ],
                header: SettingsListSectionHeader(title: "Dev Overrides")
            )
        )
    }

    private func createStoreCountryCodeItem() -> SettingsListItem {
        SettingsListItem(
            id: "country_code_region",
            title: SettingsListItemTitle("Store country code"),
            accessory: .text(
                SettingsListItemTextAccessory(text: storeCountryCode ?? "")
            ),
            onTap: { [weak self] _ in
                self?.didSelectStoreCountryCode? {
                    guard let self else { return }
                    Task {
                        self.storeCountryCode = await self.appInfoProvider.storeCountryCode
                    }
                }
            }
        )
    }

    private func createDeviceCountryCodeItem() -> SettingsListItem {
        SettingsListItem(
            id: "country_code_device",
            title: SettingsListItemTitle("Device country code"),
            accessory: .text(
                SettingsListItemTextAccessory(text: appInfoProvider.deviceCountryCode ?? "")
            ),
            onTap: { [weak self] _ in
                self?.didSelectDeviceCountryCode? {
                    guard let self else { return }
                    self.deviceCountryCode = self.appInfoProvider.deviceCountryCode
                }
            }
        )
    }

    private func createShowTouchesItem() -> SettingsListItem {
        let action: @MainActor (Bool) -> Void = { isOn in
            TKAppPreferences.showTouches = isOn
            TKDevPreferencesManager.shared.showsTouches = isOn
        }

        return createSwitchItem(
            title: "Show touches",
            id: .showTouchesItemIdentifier,
            isOn: TKAppPreferences.showTouches,
            action: action
        )
    }

    private func sendStatsImmediatelyItem() -> SettingsListItem {
        let selectedValue = TKAppPreferences.sendStatsImmediately
        let applyValue: (Bool?) -> Void = { [weak self] value in
            TKAppPreferences.sendStatsImmediately = value
            guard let self else { return }
            let state = self.createState()
            self.didUpdateState?(state)
        }

        return SettingsListItem(
            id: .sendStatsImmediatelyItemIdentifier,
            title: SettingsListItemTitle("Send Stats Immediately"),
            accessory: .menu(
                SettingsListItemMenuAccessory(
                    label: SettingsListItemTextAccessory(text: selectedValue.displayText),
                    options: [
                        SettingsListItemMenuOption(
                            title: "default",
                            isSelected: selectedValue == nil,
                            action: { applyValue(nil) }
                        ),
                        SettingsListItemMenuOption(
                            title: "force true",
                            isSelected: selectedValue == true,
                            action: { applyValue(true) }
                        ),
                        SettingsListItemMenuOption(
                            title: "force false",
                            isSelected: selectedValue == false,
                            action: { applyValue(false) }
                        ),
                    ]
                )
            )
        )
    }
}

private extension SettingsListDevMenuConfigurator {
    private func createSwitchItem(
        title: String,
        id: String,
        isOn: Bool,
        action: @escaping @MainActor (Bool) -> Void
    ) -> SettingsListItem {
        SettingsListItem(
            id: id,
            title: SettingsListItemTitle(title),
            accessory: .toggle(
                SettingsListItemToggleAccessory(
                    isOn: isOn,
                    onToggle: { [weak self] isOn in
                        Task { @MainActor in
                            action(isOn)
                            guard let self else { return }
                            let state = self.createState()
                            self.didUpdateState?(state)
                        }
                    }
                )
            )
        )
    }
}

private extension Optional where Wrapped == Bool {
    var displayText: String {
        switch self {
        case .none:
            return "Default"
        case .some(true):
            return "True"
        case .some(false):
            return "False"
        }
    }
}

private extension LogSeverity {
    var displayText: String {
        switch self {
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }
}

private extension String {
    static let version4SeedPhrasesIdentifier = "version4SeedPhrasesIdentifier"
    static let version5SeedPhrasesIdentifier = "version5SeedPhrasesIdentifier"
    static let resetWatchedStoriesIdentifier = "resetWatchedStoriesIdentifier"
    static let resetDismissedBannersIdentifier = "resetDismissedBannersIdentifier"
    static let confirmationSliderItemIdentifier = "confirmationSliderItemIdentifier"
    static let sendStatsImmediatelyItemIdentifier = "sendStatsImmediately"
    static let exportLogsIdentifier = "exportLogsIdentifier"
    static let firebaseInstallationIDIdentifier = "firebaseInstallationIDIdentifier"
    static let firebaseUserIDIdentifier = "firebaseUserIDIdentifier"
    static let buildVersionItemIdentifier = "buildVersionItemIdentifier"
    static let loggingSeverityItemIdentifier = "loggingSeverityItemIdentifier"
    static let mysteryRaffleItemIdentifier = "mysteryRaffleItemIdentifier"
    static let showTouchesItemIdentifier = "showTouchesItemIdentifier"
    static let importTestnetWalletItemIdentifier = "importTestnetWalletItemIdentifier"
    static let tooltipsItemIdentifier = "tooltipsItemIdentifier"
    static let featureFlagsItemIdentifier = "featureFlagsItemIdentifier"
    static let designSystemItemIdentifier = "designSystemItemIdentifier"
    static let toastTestingItemIdentifier = "toastTestingItemIdentifier"
}
