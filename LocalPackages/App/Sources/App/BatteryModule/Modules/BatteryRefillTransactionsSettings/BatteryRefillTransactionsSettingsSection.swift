import UIKit
import TKUIKit

enum BatteryRefillTransactionsSettings {
  enum SnapshotSection: Hashable {
    case title
    case listItems
  }
  
  enum SnapshotItem: Hashable {
    case title(TKTitleDescriptionCell.Configuration)
    case listItem(ListItem)
  }

  struct ListItem: Hashable {
    let identifier: String
    let accessory: TKListItemAccessory
    let cellConfiguration: TKListItemCell.Configuration
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
    
    init(identifier: String,
         accessory: TKListItemAccessory,
         cellConfiguration: TKListItemCell.Configuration) {
      self.identifier = identifier
      self.accessory = accessory
      self.cellConfiguration = cellConfiguration
    }
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
  typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
