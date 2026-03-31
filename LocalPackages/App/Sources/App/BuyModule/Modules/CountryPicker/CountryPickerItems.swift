import TKUIKit
import UIKit

enum CountryPicker {
    enum Section {
        case recent
        case all
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

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
}
