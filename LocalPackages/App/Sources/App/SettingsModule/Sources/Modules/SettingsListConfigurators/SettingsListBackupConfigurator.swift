import BigInt
import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListBackupConfigurator: SettingsListConfigurator {
    var didTapShowRecoveryPhrase: (() -> Void)?
    var didTapBackupManually: (() -> Void)?

    // MARK: - SettingsListConfigurator

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
        return .items(SettingsListItemsSection(
            items: items,
            header: SettingsListSectionHeader(
                title: TKLocales.Backup.Information.title,
                caption: TKLocales.Backup.Information.subtitle
            )
        ))
    }

    private func createShowRecoveryPhraseSection() -> SettingsListSection? {
        guard wallet.setupSettings.backupDate != nil else { return nil }
        return .items(SettingsListItemsSection(
            items: [.listItem(createShowRecoveryPhraseItem())]
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
        return .items(SettingsListItemsSection(
            items: [.banner(item)]
        ))
    }

    private func createBackUpOnItem(date: Date) -> SettingsListItem {
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let caption = dateFormatter.string(from: date)

        return SettingsListItem(
            id: .backupDoneItemIdentifier,
            icon: .image(
                SettingsListItemImageIcon(
                    image: SwiftUI.Image.TKUIKit.Icons.Size28.donemark,
                    tintColor: .fixed(.white),
                    backgroundColor: .accentGreen,
                    imageSize: CGSize(width: 28, height: 28)
                )
            ),
            title: SettingsListItemTitle(TKLocales.Backup.Done.title),
            captions: [SettingsListItemCaption(caption)],
            accessory: .chevron,
            onTap: { [weak self] _ in
                self?.didTapBackupManually?()
            }
        )
    }

    private func createBackupManuallyItem(state: BalanceBackupWarningCheck.State) -> SettingsListButtonItem {
        let appearance: ButtonView.Appearance
        switch state {
        case .error, .warning:
            appearance = .primary
        case .none:
            appearance = .secondary
        }

        return SettingsListButtonItem(
            id: .backupManualyItemIdentifier,
            title: TKLocales.Backup.Manually.button,
            appearance: appearance,
            action: { [weak self] in
                self?.didTapBackupManually?()
            }
        )
    }

    private func createShowRecoveryPhraseItem() -> SettingsListItem {
        SettingsListItem(
            id: .showRecoveryPhraseItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Backup.ShowPhrase.title),
            accessory: .icon(.TKUIKit.Icons.Size28.key, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                self?.didTapShowRecoveryPhrase?()
            }
        )
    }

    private func createBackupNotificationWarning(
        state: BalanceBackupWarningCheck.State,
        processedBalanceTonItem: ProcessedBalanceTonItem?
    ) -> SettingsListBannerItem? {
        let convertedAmount: String = {
            guard let processedBalanceTonItem else {
                return ""
            }
            return amountFormatter.format(
                decimal: processedBalanceTonItem.converted,
                accessory: .fiat(processedBalanceTonItem.currency),
                style: .fiatBalance
            )
        }()

        let bannerState: NotificationBanner.State
        switch state {
        case .none: return nil
        case .error:
            bannerState = .accentRed
        case .warning:
            bannerState = .accentOrange
        }
        return SettingsListBannerItem(
            id: .backupNotificationWarningIdentifier,
            content: NotificationBannerContent(
                title: nil,
                description: TKLocales.Backup.Balance.warning(convertedAmount),
                state: bannerState
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
