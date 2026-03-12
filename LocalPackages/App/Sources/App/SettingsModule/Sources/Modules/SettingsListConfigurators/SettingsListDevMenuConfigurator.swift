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

    var didSelectStoreCountryCode: ((_ completion: @escaping () -> Void) -> Void)?
    var didSelectDeviceCountryCode: ((_ completion: @escaping () -> Void) -> Void)?

    // MARK: - SettingsListV2Configurator

    var title: String {
        "Dev Menu"
    }

    var isSelectable: Bool {
        false
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
    private let appInfoProvider: KeeperCore.AppInfoProvider

    init(
        uniqueIdProvider: UniqueIdProvider,
        storiesService: StoriesService,
        appInfoProvider: KeeperCore.AppInfoProvider
    ) {
        self.uniqueIdProvider = uniqueIdProvider
        self.storiesService = storiesService
        self.appInfoProvider = appInfoProvider
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
        return SettingsListSection.listItems(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem)
        ))
    }

    private func createCacheSection() -> SettingsListSection {
        let items = [
            createResetWatchedStories(),
        ]
        return SettingsListSection.listItems(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem)
        ))
    }

    private func createLogsSection() -> SettingsListSection {
        let items = [
            createExportLogsItem(),
        ]
        return SettingsListSection.listItems(
            SettingsListItemsSection(
                items: items.map(SettingsListItemsSectionItem.listItem),
                headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Logs")
            )
        )
    }

    private func createRNSeedPhrasesItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "Pre 5.0.0 seed phrases recovery")
                )
            )
        )
        return SettingsListItem(
            id: .version4SeedPhrasesIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .none,
            onSelection: { [weak self] _ in
                self?.didSelectRNSeedPhrasesRecovery?()
            }
        )
    }

    private func createSeedPhraseRecoveryItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "5 version seed phrases recovery")
                )
            )
        )
        return SettingsListItem(
            id: .version5SeedPhrasesIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .none,
            onSelection: { [weak self] _ in
                self?.didSelectSeedPhrasesRecovery?()
            }
        )
    }

    private func createResetWatchedStories() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "Reset watched stories")
                )
            )
        )
        return SettingsListItem(
            id: .resetWatchedStoriesIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .none,
            onSelection: { [weak self] _ in
                self?.storiesService.resetShownStories()
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Reseted"))
            }
        )
    }

    private func createExportLogsItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: "Export logs")
                )
            )
        )
        return SettingsListItem(
            id: .exportLogsIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .none,
            onSelection: { [weak self] _ in
                self?.didSelectExportLogs?()
            }
        )
    }

    private func createLoggingSeverityItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: "Minimum severity"
                    )
                )
            )
        )

        let selectedValue = Log.configuration.minimumSeverity
        let applyValue: (LogSeverity) -> Void = { [weak self] value in
            TKFeatureFlags.localProvider.minimumLogSeverityRawValue = value.rawValue
            guard let self else { return }
            Log.configure()
            let state = self.createState()
            self.didUpdateState?(state)
        }

        let menu = UIMenu(children: [
            UIAction(
                title: "debug",
                state: selectedValue == .debug ? .on : .off,
                handler: { _ in
                    applyValue(.debug)
                }
            ),
            UIAction(
                title: "info",
                state: selectedValue == .info ? .on : .off,
                handler: { _ in
                    applyValue(.info)
                }
            ),
            UIAction(
                title: "warning",
                state: selectedValue == .warning ? .on : .off,
                handler: { _ in
                    applyValue(.warning)
                }
            ),
            UIAction(
                title: "error",
                state: selectedValue == .error ? .on : .off,
                handler: { _ in
                    applyValue(.error)
                }
            ),
        ])

        return SettingsListItem(
            id: .loggingSeverityItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .text(
                TKListItemTextAccessoryView.Configuration(
                    text: selectedValue.displayText,
                    color: .Text.primary,
                    textStyle: .body2,
                    menu: menu
                )
            ),
            onSelection: nil
        )
    }

    private func clearCookiesItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: "Clear cookies"
                    )
                )
            )
        )
        return SettingsListItem(
            id: .clearCookiesItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .none,
            onSelection: { _ in
                HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
                Log.i("[WebCacheCleaner] All cookies deleted")

                WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                    for record in records {
                        WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                        Log.i("[WebCacheCleaner] Record \(record) deleted")
                    }
                }
            }
        )
    }

    private func createWalletsSection() -> SettingsListSection {
        return SettingsListSection.listItems(
            SettingsListItemsSection(
                items: [
                    .listItem(createTetraWalletsItem()),
                ],
                headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Wallets")
            )
        )
    }

    private func createTetraWalletsItem() -> SettingsListItem {
        let action: (Bool) -> Void = { isOn in
            TKFeatureFlags.localProvider.isTetraWalletEnabled = isOn
        }

        return createSwitchItem(
            title: "Tetra L2 wallets",
            id: .tetraWalletsItemIdentifier,
            isOn: TKFeatureFlags.localProvider.isTetraWalletEnabled,
            action: action
        )
    }

    private func createConfirmationSection() -> SettingsListSection {
        return SettingsListSection.listItems(
            SettingsListItemsSection(
                items: [
                    .listItem(createConfirmationSliderItem()),
                ],
                headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Confirmation")
            )
        )
    }

    private func createConfirmationSliderItem() -> SettingsListItem {
        let action: (Bool) -> Void = { isOn in
            TKFeatureFlags.localProvider.isConfirmButtonInsteadSlider = !isOn
        }

        return createSwitchItem(
            title: "Slider",
            id: .confirmationSliderItemIdentifier,
            isOn: !TKFeatureFlags.localProvider.isConfirmButtonInsteadSlider,
            action: action
        )
    }

    private func createDevOverridesSection() -> SettingsListSection? {
        guard !UIApplication.shared.isAppStoreEnvironment else { return nil }

        return SettingsListSection.listItems(
            SettingsListItemsSection(
                items: [
                    .listItem(createStoreCountryCodeItem()),
                    .listItem(createDeviceCountryCodeItem()),
                    .listItem(sendStatsImmediatelyItem()),
                    .listItem(createLoggingSeverityItem()),
                ],
                headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Dev Overrides")
            )
        )
    }

    private func createStoreCountryCodeItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: "Store country code"
                    )
                )
            )
        )

        let action: () -> Void = { [weak self] in
            self?.didSelectStoreCountryCode? {
                guard let self else { return }
                Task {
                    self.storeCountryCode = await self.appInfoProvider.storeCountryCode
                }
            }
        }

        return SettingsListItem(
            id: "country_code_region",
            cellConfiguration: cellConfiguration,
            accessory:
            .text(
                TKListItemTextAccessoryView.Configuration(
                    text: self.storeCountryCode,
                    color: .Text.primary,
                    textStyle: .body2
                )
            ),
            onSelection: { _ in
                action()
            }
        )
    }

    private func createDeviceCountryCodeItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: "Device country code"
                    )
                )
            )
        )

        let action: () -> Void = { [weak self] in
            self?.didSelectDeviceCountryCode? {
                guard let self else { return }
                self.deviceCountryCode = self.appInfoProvider.deviceCountryCode
            }
        }

        let countryCode = appInfoProvider.deviceCountryCode

        return SettingsListItem(
            id: "country_code_device",
            cellConfiguration: cellConfiguration,
            accessory:
            .text(
                TKListItemTextAccessoryView.Configuration(
                    text: countryCode,
                    color: .Text.primary,
                    textStyle: .body2
                )
            ),
            onSelection: { _ in
                action()
            }
        )
    }

    private func sendStatsImmediatelyItem() -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: "Send Stats Immediately"
                    )
                )
            )
        )

        let selectedValue = TKFeatureFlags.localProvider.sendStatsImmediately
        let applyValue: (Bool?) -> Void = { [weak self] value in
            TKFeatureFlags.localProvider.sendStatsImmediately = value
            guard let self else { return }
            let state = self.createState()
            self.didUpdateState?(state)
        }
        let menu = UIMenu(children: [
            UIAction(
                title: "default",
                state: selectedValue == nil ? .on : .off,
                handler: { _ in
                    applyValue(nil)
                }
            ),
            UIAction(
                title: "force true",
                state: selectedValue == true ? .on : .off,
                handler: { _ in
                    applyValue(true)
                }
            ),
            UIAction(
                title: "force false",
                state: selectedValue == false ? .on : .off,
                handler: { _ in
                    applyValue(false)
                }
            ),
        ])

        return SettingsListItem(
            id: .sendStatsImmediatelyItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .text(
                TKListItemTextAccessoryView.Configuration(
                    text: selectedValue.displayText,
                    color: .Text.primary,
                    textStyle: .body2,
                    menu: menu
                )
            ),
            onSelection: nil
        )
    }
}

private extension SettingsListDevMenuConfigurator {
    private func createSwitchItem(
        title: String,
        id: String,
        isOn: Bool,
        action: @escaping (Bool) -> Void
    ) -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: title)
                )
            )
        )
        return SettingsListItem(
            id: id,
            cellConfiguration: cellConfiguration,
            accessory: .switch(
                TKListItemSwitchAccessoryView.Configuration(
                    isOn: isOn,
                    isEnable: true,
                    action: { isEnabled in
                        action(isEnabled)
                    }
                )
            ),
            onSelection: { [weak self] _ in
                guard let self else { return }
                action(!isOn)
                let state = self.createState()
                self.didUpdateState?(state)
            }
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

private extension Optional where Wrapped == LogSeverity {
    var displayText: String {
        switch self {
        case .none:
            return "Default"
        case let .some(value):
            return value.displayText
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
    static let clearCookiesItemIdentifier = "clearCookiesItemIdentifier"
    static let confirmationSliderItemIdentifier = "confirmationSliderItemIdentifier"
    static let sendStatsImmediatelyItemIdentifier = "sendStatsImmediately"
    static let exportLogsIdentifier = "exportLogsIdentifier"
    static let loggingSeverityItemIdentifier = "loggingSeverityItemIdentifier"
    static let tetraWalletsItemIdentifier = "tetraWalletsItemIdentifier"
}
