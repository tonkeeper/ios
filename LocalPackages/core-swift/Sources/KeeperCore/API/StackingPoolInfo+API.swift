import Foundation
import TonSwift
import TonAPI

extension StackingPoolInfo {
  init(accountStakingInfo: TonAPI.PoolInfo, implementations: [String: TonAPI.PoolImplementation]) throws {
    self.address = try Address.parse(accountStakingInfo.address)
    self.name = accountStakingInfo.name
    self.totalAmount = accountStakingInfo.totalAmount
    self.implementation = try StackingPoolInfo.Implementation(
      implemenetationType: accountStakingInfo.implementation,
      implementation: implementations[accountStakingInfo.implementation.rawValue]
    )
    self.apy = Decimal(accountStakingInfo.apy)
    self.minStake = accountStakingInfo.minStake
    self.cycleStart = TimeInterval(accountStakingInfo.cycleStart)
    self.cycleEnd = TimeInterval(accountStakingInfo.cycleEnd)
    self.isVerified = accountStakingInfo.verified
    self.currentNominators = Int64(accountStakingInfo.currentNominators)
    self.maxNominators = Int64(accountStakingInfo.maxNominators)
    if let liquidJettonMaster = accountStakingInfo.liquidJettonMaster {
      self.liquidJettonMaster = try Address.parse(liquidJettonMaster)
    } else {
      self.liquidJettonMaster = nil
    }
    self.nominatorsStake = accountStakingInfo.nominatorsStake
    self.validatorStake = accountStakingInfo.validatorStake
    if let cycleLength = accountStakingInfo.cycleLength {
      self.cycleLength = TimeInterval(cycleLength)
    } else {
      self.cycleLength = nil
    }
  }
}

extension StackingPoolInfo.Implementation {
  enum Error: Swift.Error {
    case unknownStakingPool
  }
  
  init(implemenetationType: TonAPI.PoolImplementationType,
       implementation: TonAPI.PoolImplementation?) throws {
    switch implemenetationType {
    case .whales:
      self.type = .whales
    case .tf:
      self.type = .tf
    case .liquidtf:
      self.type = .liquidTF
    case .unknownDefaultOpenApi:
      throw Error.unknownStakingPool
    }
    
    self.name = implementation?.name ?? ""
    self.description = implementation?.description ?? ""
    self.urlString = implementation?.url ?? ""
    self.socials = implementation?.socials ?? []
  }
}
