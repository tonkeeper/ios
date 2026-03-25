import KeeperCore
import StoreKit
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol BatteryRefillTransactionsSettingsModuleOutput: AnyObject {}

protocol BatteryRefillTransactionsSettingsModuleInput: AnyObject {}

protocol BatteryRefillTransactionsSettingsViewModel: AnyObject {
    var didUpdateSnapshot: ((BatteryRefillTransactionsSettings.Snapshot) -> Void)? { get set }

    func viewDidLoad()
}

final class BatteryRefillTransactionsSettingsViewModelImplementation: BatteryRefillTransactionsSettingsViewModel, BatteryRefillTransactionsSettingsModuleOutput, BatteryRefillTransactionsSettingsModuleInput {
    // MARK: - BatteryRefillTransactionsSettingsViewModel

    var didUpdateSnapshot: ((BatteryRefillTransactionsSettings.Snapshot) -> Void)?
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?

    func viewDidLoad() {
        if let wallet = try? walletsStore.activeWallet {
            let batterySettings = wallet.batterySettings
            let snapshot = createSnapshot(
                wallet: wallet,
                configuration: configuration,
                batterySettings: batterySettings
            )
            didUpdateSnapshot?(snapshot)
        }
    }

    private let walletsStore: WalletsStore
    private let configuration: Configuration
    private let keeperInfoStore: KeeperInfoStore
    private let batteryChargesMapper: BatteryChargesMapper

    init(
        walletsStore: WalletsStore,
        configuration: Configuration,
        keeperInfoStore: KeeperInfoStore,
        batteryChargesMapper: BatteryChargesMapper
    ) {
        self.walletsStore = walletsStore
        self.configuration = configuration
        self.keeperInfoStore = keeperInfoStore
        self.batteryChargesMapper = batteryChargesMapper
    }

    private func createSnapshot(
        wallet: Wallet,
        configuration: Configuration,
        batterySettings: BatterySettings
    ) -> BatteryRefillTransactionsSettings.Snapshot {
        var snapshot = BatteryRefillTransactionsSettings.Snapshot()

        snapshot.appendSections([.title])
        snapshot.appendItems(
            [.title(
                TKTitleDescriptionCell.Configuration(
                    model: TKTitleDescriptionView.Model(
                        title: TKLocales.Battery.Settings.title,
                        bottomDescription: TKLocales.Battery.Settings.caption
                    ),
                    padding: NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 32,
                        bottom: 16,
                        trailing: 32
                    )
                )
            )],
            toSection: .title
        )

        snapshot.appendSections([.listItems])
        let items = wallet.supportedBatteryTransactions.map { transaction in
            let caption = batteryChargesMapper.getChargesCountString(transaction: transaction, wallet: wallet)
            let cellConfiguration = TKListItemCell.Configuration(
                listItemContentViewConfiguration: TKListItemContentView.Configuration(
                    textContentViewConfiguration: TKListItemTextContentView.Configuration(
                        titleViewConfiguration: TKListItemTitleView.Configuration(title: transaction.name),
                        captionViewsConfigurations: [
                            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2, numberOfLines: 0),
                        ]
                    )
                )
            )

            let isOn: Bool = {
                switch transaction {
                case .swap:
                    batterySettings.isSwapTransactionEnable
                case .jetton:
                    batterySettings.isJettonTransactionEnable
                case .nft:
                    batterySettings.isNFTTransactionEnable
                case .trc20:
                    true
                }
            }()

            let isEnable: Bool
            switch transaction {
            case .swap, .nft, .jetton: isEnable = true
            case .trc20: isEnable = false
            }

            return BatteryRefillTransactionsSettings.SnapshotItem.listItem(
                BatteryRefillTransactionsSettings.ListItem(
                    identifier: transaction.rawValue,
                    accessory: .switch(
                        TKListItemSwitchAccessoryView.Configuration(
                            isOn: isOn,
                            isEnable: isEnable,
                            action: { [weak self] isOn in
                                guard let self else { return }
                                self.setTransaction(transaction: transaction, isOn: isOn)
                            }
                        )
                    ),
                    cellConfiguration: cellConfiguration
                )
            )
        }
        snapshot.appendItems(items, toSection: .listItems)

        return snapshot
    }

    private func setTransaction(transaction: BatterySupportedTransaction, isOn: Bool) {
        guard let wallet = try? walletsStore.activeWallet else { return }
        let batterySettings = {
            switch transaction {
            case .swap:
                wallet.batterySettings.setIsSwapTransactionEnable(isEnable: isOn)
            case .jetton:
                wallet.batterySettings.setIsJettonTransactionEnable(isEnable: isOn)
            case .nft:
                wallet.batterySettings.setIsNFTTransactionEnable(isEnable: isOn)
            case .trc20:
                wallet.batterySettings
            }
        }()

        walletsStore.setWalletBatterySettings(
            wallet: wallet,
            batterySettings: batterySettings,
            completion: nil
        )
    }
}
