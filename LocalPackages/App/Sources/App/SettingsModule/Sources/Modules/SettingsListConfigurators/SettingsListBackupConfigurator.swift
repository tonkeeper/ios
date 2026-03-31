import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListBackupConfigurator: SettingsListConfigurator {
    var didTapShowRecoveryPhrase: (() -> Void)?
    var didTapBackupManually: (() -> Void)?

    // MARK: - SettingsListV2Configurator

    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        TKLocales.Backup.title
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    // MARK: - Dependencies

    private var wallet: Wallet
    private let walletsStore: WalletsStore
    private let processedBalanceStore: ProcessedBalanceStore
    private let dateFormatter: DateFormatter
    private let amountFormatter: AmountFormatter

    // MARK: - Init

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        processedBalanceStore: ProcessedBalanceStore,
        dateFormatter: DateFormatter,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.processedBalanceStore = processedBalanceStore
        self.dateFormatter = dateFormatter
        self.amountFormatter = amountFormatter

        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateWalletSetupSettings(wallet):
                guard wallet == self.wallet else { return }
                DispatchQueue.main.async {
                    self.wallet = wallet
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            default: break
            }
        }
    }

    private func createState() -> SettingsListState {
        var sections = [SettingsListSection]()

        let proccessedBalance = processedBalanceStore.getState()[wallet]?.balance
        let balanceBackupWarningState = BalanceBackupWarningCheck()
            .check(
                wallet: wallet,
                tonAmount: UInt64(proccessedBalance?.tonItem.amount ?? 0)
            )

        if let backupWarningNotificationSection = createBackupWarningNotificationSection(
            state: balanceBackupWarningState,
            processedBalanceTonItem: proccessedBalance?.tonItem
        ) {
            sections.append(backupWarningNotificationSection)
        }

        sections.append(createBackupSection(state: balanceBackupWarningState))

        if let showRecoveryPhraseSection = createShowRecoveryPhraseSection() {
            sections.append(showRecoveryPhraseSection)
        }
        return SettingsListState(
            sections: sections
        )
    }

    private func createBackupSection(state: BalanceBackupWarningCheck.State) -> SettingsListSection {
        var items = [SettingsListItemsSectionItem]()
        if let backupDate = wallet.setupSettings.backupDate {
            items.append(.listItem(createBackUpOnItem(date: backupDate)))
        } else {
            items.append(.button(createBackupManuallyItem(state: state)))
        }
        return SettingsListSection.listItems(SettingsListItemsSection(
            items: items,
            headerConfiguration: SettingsListSectionHeaderView.Configuration(
                title: TKLocales.Backup.Information.title,
                caption: TKLocales.Backup.Information.subtitle
            )
        ))
    }

    private func createShowRecoveryPhraseSection() -> SettingsListSection? {
        guard wallet.setupSettings.backupDate != nil else { return nil }
        let items: [SettingsListItemsSectionItem] = [.listItem(createShowRecoveryPhraseItem())]
        return SettingsListSection.listItems(SettingsListItemsSection(
            items: items
        ))
    }

    private func createBackupWarningNotificationSection(
        state: BalanceBackupWarningCheck.State,
        processedBalanceTonItem: ProcessedBalanceTonItem?
    ) -> SettingsListSection? {
        guard let item = createBackupNotificationWarning(
            state: state,
            processedBalanceTonItem: processedBalanceTonItem
        ) else { return nil }
        return SettingsListSection.listItems(SettingsListItemsSection(
            items: [.notificationBanner(item)]
        ))
    }

    private func createBackUpOnItem(date: Date) -> SettingsListItem {
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let caption = dateFormatter.string(from: date)

        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: TKListItemIconView.Configuration(
                    content: .image(
                        TKImageView.Model(
                            image: .image(.App.Icons.Size28.donemark),
                            tintColor: .white,
                            size: .auto,
                            corners: .none
                        )
                    ),
                    alignment: .center,
                    cornerRadius: 22,
                    backgroundColor: .Accent.green,
                    size: CGSize(width: 44, height: 44)
                ),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
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
            onSelection: { [weak self] _ in
                self?.didTapBackupManually?()
            }
        )
    }

    private func createBackupManuallyItem(state: BalanceBackupWarningCheck.State) -> SettingsButtonListItem {
        var buttonConfiguration: TKButton.Configuration
        switch state {
        case .error, .warning:
            buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        case .none:
            buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        }

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
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(
                        title: TKLocales.Backup.ShowPhrase.title
                    )
                )
            )
        )

        return SettingsListItem(
            id: .showRecoveryPhraseItemIdentifier,
            cellConfiguration: cellConfiguration,
            accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.key, tintColor: .Accent.blue)),
            onSelection: { [weak self] _ in
                self?.didTapShowRecoveryPhrase?()
            }
        )
    }

    private func createBackupNotificationWarning(
        state: BalanceBackupWarningCheck.State,
        processedBalanceTonItem: ProcessedBalanceTonItem?
    ) -> SettingsNotificationBannerListItem? {
        let convertedAmount: String = {
            guard let processedBalanceTonItem else {
                return ""
            }
            return amountFormatter.format(
                decimal: processedBalanceTonItem.converted,
                accessory: .currency(processedBalanceTonItem.currency)
            )
        }()

        let appearance: NotificationBannerView.Model.Appearance
        switch state {
        case .none: return nil
        case .error:
            appearance = .accentRed
        case .warning:
            appearance = .accentYellow
        }
        return SettingsNotificationBannerListItem(
            id: .backupNotificationWarningIdentifier,
            cellConfiguration: NotificationBannerCell.Configuration(
                bannerViewConfiguration: NotificationBannerView.Model(
                    title: nil,
                    caption: TKLocales.Backup.Balance.warning(convertedAmount),
                    appearance: appearance,
                    actionButton: nil,
                    closeButton: nil
                )
            )
        )
    }
}

private extension String {
    static let backupManualyItemIdentifier = "BackupManuallyItem"
    static let backupDoneItemIdentifier = "BackupDoneItem"
    static let showRecoveryPhraseItemIdentifier = "showRecoveryPhraseItem"
    static let backupNotificationWarningIdentifier = "BackupNotificationWarningIdentifier"
}
