import UIKit
import TKUIKit

enum BrowserSearch {
  enum Section: Hashable {
    case dapps
    case suggests(headerModel: BrowserSearchListSectionHeaderView.Model)
  }
  
  struct Item: Hashable {
    let identifier: String
    let configuration: TKListItemCell.Configuration
    let isHighlighted: Bool
    let onSelection: () -> Void
    
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
