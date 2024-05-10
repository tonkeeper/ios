import Foundation

public struct BuySellOperatorItemsModel {
  public let items: [Item]
  
  public init(items: [Item]) {
    self.items = items
  }
}

public extension BuySellOperatorItemsModel {
  struct Item {
    public let identifier: String
    public let iconURL: URL?
    public let title: String
    public let description: String
    public let tagText: String?
    
    public init(identifier: String, iconURL: URL?, title: String, description: String, tagText: String? = nil) {
      self.identifier = identifier
      self.iconURL = iconURL
      self.title = title
      self.description = description
      self.tagText = tagText
    }
  }
}
