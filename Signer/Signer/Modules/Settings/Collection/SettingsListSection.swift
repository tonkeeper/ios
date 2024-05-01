import Foundation

struct SettingsListSection: Hashable {
  let id = UUID()
  let items: [SettingsListItem]
}

