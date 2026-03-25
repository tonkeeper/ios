import TKUIKit
import UIKit

enum TokenPicker {
    enum Section: Hashable {
        case tokens
    }

    struct Token: Hashable {
        let identifier: String
        let configuration: TKListItemCell.Configuration
        let selectionHandler: (() -> Void)?

        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
            hasher.combine(configuration)
        }

        static func == (lhs: Token, rhs: Token) -> Bool {
            lhs.identifier == rhs.identifier && lhs.configuration == rhs.configuration
        }
    }

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Token>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Token>
}
