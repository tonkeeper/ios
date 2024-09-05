import Foundation
import TKUIKit
import KeeperCore

enum ManageTokensSection: Hashable {
  case pinned
  case allAsstes
}

class ManageTokensListItem: Hashable {
  let identifier: String
  let canReorder: Bool
  let accessories: [TKListItemAccessory]
  
  static func == (lhs: ManageTokensListItem, rhs: ManageTokensListItem) -> Bool {
    lhs.identifier == rhs.identifier
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
  
  init(identifier: String,
       canReorder: Bool,
       accessories: [TKListItemAccessory]) {
    self.identifier = identifier
    self.canReorder = canReorder
    self.accessories = accessories
  }
}
