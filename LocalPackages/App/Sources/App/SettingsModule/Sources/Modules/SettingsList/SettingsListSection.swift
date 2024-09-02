import Foundation
import UIKit
import TKUIKit

enum SettingsListSection: Hashable {
  case listItems(SettingsListItemsSection)
  case appInformation(SettingsAppInformationCell.Configuration)
  case button(SettingsButtonListItem)
}

struct SettingsListItemsSection: Hashable {
  let items: [AnyHashable]
  let topPadding: CGFloat
  let bottomPadding: CGFloat
  let headerConfiguration: SettingsListSectionHeaderView.Configuration?
  
  init(items: [AnyHashable], 
       topPadding: CGFloat,
       bottomPadding: CGFloat,
       headerConfiguration: SettingsListSectionHeaderView.Configuration? = nil) {
    self.items = items
    self.topPadding = topPadding
    self.bottomPadding = bottomPadding
    self.headerConfiguration = headerConfiguration
  }
}

class SettingsListItem: Hashable {
  let id: String
  let cellConfiguration: TKListItemCell.Configuration
  let accessory: SettingsListItemAccessory
  let selectAccessory: SettingsListItemAccessory?
  let onSelection: ((UIView?) -> Void)?
  
  static func == (lhs: SettingsListItem, rhs: SettingsListItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  init(id: String, 
       cellConfiguration: TKListItemCell.Configuration,
       accessory: SettingsListItemAccessory,
       selectAccessory: SettingsListItemAccessory? = nil,
       onSelection: ( (UIView?) -> Void)?) {
    self.id = id
    self.cellConfiguration = cellConfiguration
    self.accessory = accessory
    self.selectAccessory = selectAccessory
    self.onSelection = onSelection
  }
}

class SettingsButtonListItem: Hashable {
  let id: String
  let cellConfiguration: TKButtonCollectionViewCell.Configuration
  
  static func == (lhs: SettingsButtonListItem, rhs: SettingsButtonListItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  init(id: String, 
       cellConfiguration: TKButtonCollectionViewCell.Configuration) {
    self.id = id
    self.cellConfiguration = cellConfiguration
  }
}

enum SettingsListItemAccessory {
  case none
  case chevron
  case icon(TKListItemIconAccessoryView.Configuration)
  case text(TKListItemTextAccessoryView.Configuration)
  case swift(TKListItemSwitchAccessoryView.Configuration)
}
