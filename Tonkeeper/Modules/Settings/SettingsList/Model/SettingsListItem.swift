//
//  SettingsListItem.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit

struct SettingsListItem {
  let title: String
  let subtitle: String?
  let option: SettingsListItemOption
  let isBadgeVisible: Bool
  
  init(title: String, subtitle: String? = nil, option: SettingsListItemOption, isBadgeVisible: Bool = false) {
    self.title = title
    self.subtitle = subtitle
    self.option = option
    self.isBadgeVisible = isBadgeVisible
  }
}

enum SettingsListItemOption {
  case plain(SettingsListItemPlainOption)
  case switchOption(SettingsListItemSwitchOption)
}

struct SettingsListItemPlainOption {
  enum Accessory {
    struct Icon {
      let image: UIImage?
      let tintColor: UIColor
    }
    case none
    case value(String)
    case icon(Icon)
    case chevron
    case checkmark
  }
  
  let accessory: Accessory
  let handler: () -> Void
}

struct SettingsListItemSwitchOption {
  let isOn: Bool
  let isEnabled: Bool
  let handler: (Bool) async -> Bool
}
