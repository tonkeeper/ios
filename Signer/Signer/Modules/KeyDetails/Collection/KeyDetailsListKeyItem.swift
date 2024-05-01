import Foundation

struct KeyDetailsListKeyItem: Identifiable, Hashable {
  let id: String
  let model: Any
  let isHighlightable: Bool
  let action: (() -> Void)?
  
  init(id: String,
       model: Any,
       isHighlightable: Bool = true,
       action: (() -> Void)? = nil) {
    self.id = id
    self.model = model
    self.isHighlightable = isHighlightable
    self.action = action
  }
  
  static func ==(lhs: KeyDetailsListKeyItem, rhs: KeyDetailsListKeyItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
