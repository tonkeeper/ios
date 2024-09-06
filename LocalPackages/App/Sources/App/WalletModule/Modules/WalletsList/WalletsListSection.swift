import UIKit
import TKUIKit

enum WalletsListSection: Hashable {
  case wallets(footerConfiguration: TKListCollectionViewButtonFooterView.Configuration)
}

struct WalletsListItem: Hashable, Equatable {
  let identifier: String
  let accessories: [TKListItemAccessory]
  let selectAccessories: [TKListItemAccessory]
  let editingAccessories: [TKListItemAccessory]
  let onSelection: (() -> Void)?
  
  static func == (lhs: WalletsListItem, rhs: WalletsListItem) -> Bool {
    lhs.identifier == rhs.identifier
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
  
  init(identifier: String,
       accessories: [TKListItemAccessory],
       selectAccessories: [TKListItemAccessory],
       editingAccessories: [TKListItemAccessory],
       onSelection: (() -> Void)? = nil) {
    self.identifier = identifier
    self.accessories = accessories
    self.selectAccessories = selectAccessories
    self.editingAccessories = editingAccessories
    self.onSelection = onSelection
  }
}

