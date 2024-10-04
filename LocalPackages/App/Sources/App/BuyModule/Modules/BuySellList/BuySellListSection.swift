import UIKit
import TKUIKit

enum BuySellListSection: Hashable {
  case items(id: Int, title: String?, assets: [UIImage?])
  case button(id: Int)
}

enum BuySellListItem: Hashable {
  case item(identifier: String)
  case button(TKButtonCell.Model)
}
