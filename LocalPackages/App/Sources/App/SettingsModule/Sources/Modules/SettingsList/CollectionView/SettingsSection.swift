import Foundation
import UIKit

struct SettingsListSection: Hashable {
  let padding: NSDirectionalEdgeInsets
  let items: [AnyHashable]
}

enum SettingsSection: Hashable {
  case settingsItems(items: [SettingsCell.Model])
}

extension NSDirectionalEdgeInsets: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(top)
    hasher.combine(leading)
    hasher.combine(bottom)
    hasher.combine(trailing)
  }
}
