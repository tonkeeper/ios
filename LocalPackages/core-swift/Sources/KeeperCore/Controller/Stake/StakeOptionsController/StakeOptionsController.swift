import UIKit
import TKUIKit

public final class StakeOptionsController {
  
  public func start() async {
    
  }
}

public struct StakePool {
  public let id: String
  public let image: UIImage
  public let title: String
  public let tag: String?
  public let apy: String
  public let minimumDeposit: String?
  
  public init(id: String, image: UIImage, title: String, tag: String?, apy: String, minimumDeposit: String?) {
    self.id = id
    self.image = image
    self.title = title
    self.tag = tag
    self.apy = apy
    self.minimumDeposit = minimumDeposit
  }
}

public struct StakePoolList {
  public let id: String
  public let image: UIImage
  public let title: String
  public let tag: String?
  public let minimumDeposit: String
  public let description: String
  public let pools: [StakePool]
  
  public init(id: String, image: UIImage, title: String, tag: String?, minimumDeposit: String, description: String, pools: [StakePool]) {
    self.id = id
    self.image = image
    self.title = title
    self.tag = tag
    self.minimumDeposit = minimumDeposit
    self.description = description
    self.pools = pools
  }
}

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
