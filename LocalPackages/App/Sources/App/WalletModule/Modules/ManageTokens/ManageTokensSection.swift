import Foundation
import KeeperCore

enum ManageTokensSection: Hashable {
  case pinned
  case allAsstes
}

enum ManageTokensItem: Hashable {
  case token(String)
}

enum ManageTokenItemState {
  case pinned
}
