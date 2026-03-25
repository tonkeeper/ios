import KeeperCore
import TKUIKit
import UIKit

enum WalletBalance {
    enum SnapshotSection: Hashable {
        case balanceHeader
        case balance(BalanceItemsSection)
        case setup(SetupSection)
        case notifications(NotificationSection)
    }

    enum SnapshotItem: Hashable {
        case balanceHeader
        case listItem(ListItem)
        case notificationItem(NotificationItem)
    }

    struct BalanceItemsSection: Hashable {
        let items: [ListItem]
        let footerConfiguration: TKListCollectionViewButtonFooterView.Configuration?

        init(
            items: [ListItem],
            footerConfiguration: TKListCollectionViewButtonFooterView.Configuration? = nil
        ) {
            self.items = items
            self.footerConfiguration = footerConfiguration
        }
    }

    struct SetupSection: Hashable {
        let items: [ListItem]
        let headerConfiguration: TKListCollectionViewButtonHeaderView.Configuration

        init(
            items: [ListItem],
            headerConfiguration: TKListCollectionViewButtonHeaderView.Configuration
        ) {
            self.items = items
            self.headerConfiguration = headerConfiguration
        }
    }

    struct NotificationSection: Hashable {
        let items: [NotificationItem]
    }

    struct ListItem: Hashable {
        let identifier: String
        let accessory: TKListItemAccessory?
        let onSelection: (() -> Void)?

        static func == (lhs: ListItem, rhs: ListItem) -> Bool {
            lhs.identifier == rhs.identifier
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }

        init(
            identifier: String,
            accessory: TKListItemAccessory? = nil,
            onSelection: (() -> Void)?
        ) {
            self.identifier = identifier
            self.accessory = accessory
            self.onSelection = onSelection
        }
    }

    class NotificationItem: Hashable {
        let id: String
        let cellConfiguration: NotificationBannerCell.Configuration

        static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        init(
            id: String,
            cellConfiguration: NotificationBannerCell.Configuration
        ) {
            self.id = id
            self.cellConfiguration = cellConfiguration
        }
    }

    typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
