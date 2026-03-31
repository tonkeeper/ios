import TKUIKit
import UIKit

enum BrowserCategory {
    enum SnapshotSection: Hashable {
        case regular(items: [Item])
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

    typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, Item>
}
