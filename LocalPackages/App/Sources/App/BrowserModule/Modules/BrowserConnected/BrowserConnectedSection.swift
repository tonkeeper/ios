import UIKit
import TKUIKit

enum BrowserConnected {

  enum Section: Hashable {
    case apps
  }

  struct Item: Hashable {
    let identifier: String
    let configuration: BrowserConnectedAppCell.Configuration
  }

  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
}
