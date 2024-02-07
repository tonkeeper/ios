import Foundation
import TKCore

enum SettingsSection: Hashable {
//  case wallet(item: WalletsListWalletCell.Model)
  case settingsItems(items: [SettingsCell.Model])
}
