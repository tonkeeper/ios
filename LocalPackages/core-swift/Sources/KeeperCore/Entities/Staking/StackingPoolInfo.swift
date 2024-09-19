import Foundation
import TonSwift
import BigInt

public struct StackingPoolInfo: Codable, Equatable {
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
  
  public let address: Address
  public let name: String
  public let totalAmount: Int64
  public let implementation: Implementation
  public let apy: Decimal
  public let minStake: Int64
  public let cycleStart: TimeInterval
  public let cycleEnd: TimeInterval
  public let isVerified: Bool
  public let currentNominators: Int64
  public let maxNominators: Int64
  public let liquidJettonMaster: Address?
  public let nominatorsStake: Int64
  public let validatorStake: Int64
  public let cycleLength: TimeInterval?
  
  init(address: Address, 
       name: String,
       totalAmount: Int64,
       implementation: Implementation,
       apy: Decimal,
       minStake: Int64,
       cycleStart: TimeInterval,
       cycleEnd: TimeInterval,
       isVerified: Bool,
       currentNominators: Int64,
       maxNominators: Int64,
       liquidJettonMaster: Address,
       nominatorsStake: Int64,
       validatorStake: Int64,
       cycleLength: TimeInterval) {
    self.address = address
    self.name = name
    self.totalAmount = totalAmount
    self.implementation = implementation
    self.apy = apy
    self.minStake = minStake
    self.cycleStart = cycleStart
    self.cycleEnd = cycleEnd
    self.isVerified = isVerified
    self.currentNominators = currentNominators
    self.maxNominators = maxNominators
    self.liquidJettonMaster = liquidJettonMaster
    self.nominatorsStake = nominatorsStake
    self.validatorStake = validatorStake
    self.cycleLength = cycleLength
  }
}

public extension Array where Element == StackingPoolInfo {
  var profitablePool: Element? {
    self.max(by: { $0.apy < $1.apy })
  }
  
  func filterByPoolKind(_ kind: StackingPoolInfo.Implementation.Kind) -> [StackingPoolInfo] {
    filter { $0.implementation.type ==  kind}
  }
}


public extension StackingPoolInfo.Implementation {
  var withdrawalFee: BigUInt  {
    switch self.type {
    case .liquidTF:
      return BigUInt(integerLiteral: 1_000_000_000)
    case .tf:
      return BigUInt(integerLiteral: 1_000_000_000)
    case .whales:
      return BigUInt(integerLiteral: 200_000_000)
    }
  }
}
