import UIKit
import TKUIKit

enum BrowserConnected {

  enum Section: Hashable {
    case apps
  }

  struct Item: Hashable {
    let identifier: String
    let title: String
    let configuration: BrowserConnectedAppCell.Configuration
    let deleteHandler: (() -> Void)?

    static func ==(lhs: Item, rhs: Item) -> Bool {
      lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
  }

  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
}
