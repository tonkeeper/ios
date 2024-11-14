import Foundation

public extension TKPopUp {
  struct Configuration {
    public let items: [TKPopUp.Item]
    public let bottomItems: [TKPopUp.Item]
    
    public init(items: [TKPopUp.Item],
                bottomItems: [TKPopUp.Item] = []) {
      self.items = items
      self.bottomItems = bottomItems
    }
    
    public static var empty: Configuration {
      Configuration(items: [])
    }
  }
}
