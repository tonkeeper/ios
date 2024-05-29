import UIKit

// MARK: - StakePool

public struct StakePool {
  public struct Link {
    public let icon: UIImage?
    public let titledUrl: TitledURL
    
    public init(icon: UIImage?, titledUrl: TitledURL) {
      self.icon = icon
      self.titledUrl = titledUrl
    }
  }
  
  public var isSelected: Bool = false
  public let id: String
  public let image: UIImage
  public let title: String
  public let tag: String?
  public let apy: String
  public var minimumDeposit: String
  public let links: [Link]
  
  public init(id: String,
              image: UIImage,
              title: String,
              tag: String?,
              apy: String,
              minimumDeposit: String,
              links: [Link] = []) {
    self.id = id
    self.image = image
    self.title = title
    self.tag = tag
    self.apy = apy
    self.minimumDeposit = minimumDeposit
    self.links = links
  }
}

// MARK: - StakePoolList

public struct StakePoolList {
  public let id: String
  public let image: UIImage
  public let title: String
  public let tag: String?
  public let minimumDeposit: String
  public let description: String
  public var pools: [StakePool]
  
  public init(id: String,
              image: UIImage,
              title: String,
              tag: String?,
              minimumDeposit: String,
              description: String,
              pools: [StakePool]) {
    self.id = id
    self.image = image
    self.title = title
    self.tag = tag
    self.minimumDeposit = minimumDeposit
    self.description = description
    self.pools = pools
  }
}

public extension Array where Element == StakePool {
  mutating func updateSelected(selectPool: StakePool) {
    self = self.map { stakePool in
      var updatedStakePool = stakePool
      updatedStakePool.isSelected = stakePool.id == selectPool.id
      return updatedStakePool
    }
  }
}

public extension Array where Element == StakePoolList {
  mutating func updateSelected(selectPool: StakePool) {
    self = self.map { stakePoolList in
      var updatedStakePoolList = stakePoolList
      updatedStakePoolList.pools.updateSelected(selectPool: selectPool)
      return updatedStakePoolList
    }
  }
}
