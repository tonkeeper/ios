import Foundation
import TonSwift

public enum StakingPoolImage {
  // Haven't found pool implementation logo in API.
  // So decided to hardcode image here
  case fromResource
  case url(URL?)
}

public struct StakingPool: Codable, Hashable {
  public let address: Address
  public let name: String
  public let apy: Decimal
  public let minStake: Int64
  public let cycleEnd: Int64
  public let cycleStart: Int64
  public let jettonMaster: Address?
  public let implementation: Implementation
  
  public struct Implementation: Codable, Hashable {
    public enum Kind: String, CaseIterable, Codable {
      case liquidTF
      case whales
      case tf
    }
    
    public let type: Kind
    public let name: String
    public let description: String
    public let urlString: String
    public let socials: [String]
  }
}

public extension Array where Element == StakingPool {
  func filterByPoolKind(_ kind: StakingPool.Implementation.Kind) -> [StakingPool] {
    filter { $0.implementation.type ==  kind}
  }
  
  var mostProfitablePool: Element? {
    self.max(by: { $0.apy < $1.apy })
  }
}

