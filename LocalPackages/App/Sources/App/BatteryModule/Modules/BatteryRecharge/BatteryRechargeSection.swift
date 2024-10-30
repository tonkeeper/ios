import UIKit
import TKUIKit

enum BatteryRecharge {
  enum SnapshotSection: Hashable {
    case options
    case continueButton
  }
  
  enum SnapshotItem: Hashable {
    case listItem(ListItem)
    case continueButton
  }

  struct ListItem: Hashable {
    let identifier: String
    let isEnable: Bool
    let batteryViewState: BatteryView.State
    let onSelection: () -> Void
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
      lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
    
    init(identifier: String,
         isEnable: Bool,
         batteryViewState: BatteryView.State,
         onSelection: @escaping () -> Void) {
      self.identifier = identifier
      self.isEnable = isEnable
      self.batteryViewState = batteryViewState
      self.onSelection = onSelection
    }
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
  typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
