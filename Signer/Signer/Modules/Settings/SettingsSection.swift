import Foundation

struct SettingsSection: Hashable {
  let title: String?
  let items: [AnyHashable]
  
  init(title: String? = nil, items: [AnyHashable]) {
    self.title = title
    self.items = items
  }
}
