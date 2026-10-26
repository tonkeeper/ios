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
    private let dateFormatter: DateFormatter

    // MARK: - Init

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        dateFormatter: DateFormatter
    ) {
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.dateFormatter = dateFormatter

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

        sections.append(createBackupSection())

        if let showRecoveryPhraseSection = createShowRecoveryPhraseSection() {
            sections.append(showRecoveryPhraseSection)
        }
        return SettingsListState(
            sections: sections
        )
    }

    private func createBackupSection() -> SettingsListSection {
        var items = [SettingsListItemsSectionItem]()
        if let backupDate = wallet.setupSettings.backupDate {
            items.append(.listItem(createBackUpOnItem(date: backupDate)))
        } else {
            items.append(.button(createBackupManuallyItem()))
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

    private func createBackupManuallyItem() -> SettingsListButtonItem {
        SettingsListButtonItem(
            id: .backupManualyItemIdentifier,
            title: TKLocales.Backup.Manually.button,
            appearance: .secondary,
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
}

private extension String {
    static let backupManualyItemIdentifier = "BackupManuallyItem"
    static let backupDoneItemIdentifier = "BackupDoneItem"
    static let showRecoveryPhraseItemIdentifier = "showRecoveryPhraseItem"
}
