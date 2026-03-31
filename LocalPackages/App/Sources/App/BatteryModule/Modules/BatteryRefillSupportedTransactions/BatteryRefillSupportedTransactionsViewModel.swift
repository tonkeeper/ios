import KeeperCore
import StoreKit
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol BatteryRefillSupportedTransactionsModuleOutput: AnyObject {}

protocol BatteryRefillSupportedTransactionsModuleInput: AnyObject {}

protocol BatteryRefillSupportedTransactionsViewModel: AnyObject {
    var didUpdateSnapshot: ((BatteryRefillSupportedTransactions.Snapshot) -> Void)? { get set }
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }

    func viewDidLoad()
}

final class BatteryRefillSupportedTransactionsViewModelImplementation: BatteryRefillSupportedTransactionsViewModel, BatteryRefillSupportedTransactionsModuleOutput, BatteryRefillSupportedTransactionsModuleInput {
    // MARK: - BatteryRefillSupportedTransactionsViewModel

    var didUpdateSnapshot: ((BatteryRefillSupportedTransactions.Snapshot) -> Void)?
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?

    func viewDidLoad() {
        didUpdateTitleView?(
            TKUINavigationBarTitleView.Model(
                title: TKLocales.Battery.Refill.transactions
            )
        )

        let snapshot = createSnapshot()
        didUpdateSnapshot?(snapshot)
    }

    private let wallet: Wallet
    private let batteryChargeMapper: BatteryChargesMapper

    init(
        wallet: Wallet,
        batteryChargeMapper: BatteryChargesMapper
    ) {
        self.wallet = wallet
        self.batteryChargeMapper = batteryChargeMapper
    }

    private func createSnapshot() -> BatteryRefillSupportedTransactions.Snapshot {
        var snapshot = BatteryRefillSupportedTransactions.Snapshot()

        snapshot.appendSections([.listItems])
        let items = wallet.supportedBatteryTransactions.map { transaction in
            let caption = batteryChargeMapper.getChargesCountString(transaction: transaction, wallet: wallet)
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
            return BatteryRefillSupportedTransactions.SnapshotItem(
                identifier: transaction.rawValue,
                cellConfiguration: cellConfiguration
            )
        }
        snapshot.appendItems(items, toSection: .listItems)

        return snapshot
    }
}
