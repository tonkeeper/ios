import UIKit
import TKUIKit

enum BatteryRefill {
  enum SnapshotSection: Hashable {
    case inAppPurchases
    case rechargeMethods
    case history
    
    var isSelectable: Bool {
      switch self {
      case .inAppPurchases:
        false
      case .rechargeMethods, .history:
        true
      }
    }
  }
  
  enum SnapshotItem: Hashable {
    case inAppPurchase(InAppPurchaseItem)
    case listItem(ListItem)
  }
  
  struct InAppPurchaseItem: Hashable {
    let identifier: String
    let batteryPercent: CGFloat
    let buttonTitle: String
    let isEnable: Bool
  }

  struct ListItem: Hashable {
    let identifier: String
    let onSelection: (() -> Void)?
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
    
    init(identifier: String,
         onSelection: (() -> Void)?) {
      self.identifier = identifier
      self.onSelection = onSelection
    }
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
  typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
