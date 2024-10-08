import Foundation

public extension TKPopUp {
  struct Configuration {
    public let items: [TKPopUp.Item]
    
    public init(items: [TKPopUp.Item]) {
      self.items = items
    }
    
    public static var empty: Configuration {
      Configuration(items: [])
    }
  }
}
