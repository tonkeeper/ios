import Foundation

struct SettingsListSection: Hashable {
  let items: [AnyHashable]
}

enum SettingsSection: Hashable {
  case wallet(item: WalletsListWalletCell.Model)
  case settingsItems(items: [SettingsCell.Model])
}
