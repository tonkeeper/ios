struct SettingsListItem: Identifiable, Hashable {
  let id: String
  let model: AccessoryListItemView<TwoLinesListItemView>.Model
  let action: (() -> Void)?
  
  init(id: String,
       model: AccessoryListItemView<TwoLinesListItemView>.Model,
       action: (() -> Void)? = nil) {
    self.id = id
    self.model = model
    self.action = action
  }
  
  static func ==(lhs: SettingsListItem, rhs: SettingsListItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
