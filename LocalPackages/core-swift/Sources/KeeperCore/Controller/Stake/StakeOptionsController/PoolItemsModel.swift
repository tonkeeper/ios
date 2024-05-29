import Foundation

public struct PoolItemsModel {
  public let items: [StakePool]
  public init(items: [StakePool]) {
    self.items = items
  }
}

public struct PoolListItemsModel {
  public let items: [StakePoolList]
  public init(items: [StakePoolList]) {
    self.items = items
  }
}
