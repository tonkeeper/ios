import Foundation

public struct FiatOperatorItemsModel {
  public let fiatOperatorItems: [Item]
  
  public init(fiatOperatorItems: [Item]) {
    self.fiatOperatorItems = fiatOperatorItems
  }
}

public extension FiatOperatorItemsModel {
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
