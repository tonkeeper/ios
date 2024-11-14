import UIKit
import TKUIKit

enum BatteryRecharge {
  enum SnapshotSection: Hashable {
    case options
    case customInput
    case continueButton
    case promocode
    case recipient
  }
  
  enum SnapshotItem: Hashable {
    case rechargeOption(RechargeOptionItem)
    case customInput
    case continueButton
    case promocode
    case recipient
  }

  struct RechargeOptionItem: Hashable {
    let identifier: String
    let listCellConfiguration: TKListItemCell.Configuration
    let isEnable: Bool
    let batteryViewState: BatteryView.State
    let onSelection: () -> Void
    
    static func == (lhs: RechargeOptionItem, rhs: RechargeOptionItem) -> Bool {
      lhs.identifier == rhs.identifier
      && lhs.listCellConfiguration == rhs.listCellConfiguration
      && lhs.isEnable == rhs.isEnable
      && lhs.batteryViewState == rhs.batteryViewState
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
      hasher.combine(listCellConfiguration)
      hasher.combine(isEnable)
      hasher.combine(batteryViewState)
    }
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
  typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
