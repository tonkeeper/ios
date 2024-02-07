import Foundation

enum SettingsSection: Hashable {
  case wallet(item: WalletsListWalletCell.Model)
  case settingsItems(items: [SettingsCell.Model])
}
