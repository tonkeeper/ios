import UIKit
import TKUIKit

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
    }
    
    static func ==(lhs: Token, rhs: Token) -> Bool {
      lhs.identifier == rhs.identifier
    }
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Token>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Token>
}
