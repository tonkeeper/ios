import UIKit
import TKUIKit

enum BatteryRefillSupportedTransactions {
  enum SnapshotSection: Hashable {
    case listItems
  }

  struct SnapshotItem: Hashable {
    let identifier: String
    let cellConfiguration: TKListItemCell.Configuration
    
    static func == (lhs: SnapshotItem, rhs: SnapshotItem) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
    
    init(identifier: String,
         cellConfiguration: TKListItemCell.Configuration) {
      self.identifier = identifier
      self.cellConfiguration = cellConfiguration
    }
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
  typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
