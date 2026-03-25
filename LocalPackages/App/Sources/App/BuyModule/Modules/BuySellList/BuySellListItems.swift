import TKUIKit
import UIKit

enum BuySellList {
    enum SnapshotSection: Hashable {
        case items(id: Int, title: String?, assets: [UIImage?])
        case button(id: Int)
    }

    enum SnapshotItem: Hashable {
        case item(Item)
        case button(TKButtonCell.Model)
    }

    struct Item: Hashable {
        let identifier: String
        let configuration: TKListItemCell.Configuration
        let selectionHandler: (() -> Void)?

        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
            hasher.combine(configuration)
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.identifier == rhs.identifier && lhs.configuration == rhs.configuration
        }
    }

    typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
