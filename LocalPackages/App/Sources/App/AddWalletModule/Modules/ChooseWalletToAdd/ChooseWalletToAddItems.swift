import UIKit
import TKUIKit

struct ChooseWalletToAddSection: Hashable {
  let items: [ChooseWalletToAddItem]
}

struct ChooseWalletToAddItem: Hashable {
  let identifier: String
  let isSelectionEnable: Bool
  let cellConfiguration: TKListItemCell.Configuration
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
  
  static func == (lhs: ChooseWalletToAddItem, rhs: ChooseWalletToAddItem) -> Bool {
    lhs.identifier == rhs.identifier
  }
}
