import Foundation
import UIKit
import TKUIKit

enum SettingsListSection: Hashable {
  case listItems(SettingsListItemsSection)
  case appInformation(SettingsAppInformationCell.Configuration)
}

struct SettingsListItemsSection: Hashable {
  let items: [SettingsListItem]
  let topPadding: CGFloat
  let bottomPadding: CGFloat
}

class SettingsListItem: Hashable {
  let id: String
  let cellConfiguration: TKListItemCell.Configuration
  let accessory: SettingsListItemAccessory
  let onSelection: ((UIView?) -> Void)?
  
  static func == (lhs: SettingsListItem, rhs: SettingsListItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  init(id: String, cellConfiguration: TKListItemCell.Configuration, accessory: SettingsListItemAccessory, onSelection: ( (UIView?) -> Void)?) {
    self.id = id
    self.cellConfiguration = cellConfiguration
    self.accessory = accessory
    self.onSelection = onSelection
  }
}

enum SettingsListItemAccessory {
  case none
  case chevron
  case icon(TKListItemIconAccessoryView.Configuration)
  case text(TKListItemTextAccessoryView.Configuration)
  case swift(TKListItemSwitchAccessoryView.Configuration)
}
