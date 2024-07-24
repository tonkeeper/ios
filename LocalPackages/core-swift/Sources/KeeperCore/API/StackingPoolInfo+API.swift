import Foundation
import TonSwift
import TonAPI

extension StackingPoolInfo {
  init(accountStakingInfo: Components.Schemas.PoolInfo, implementations: [String: Components.Schemas.PoolImplementation]) throws {
    self.address = try Address.parse(accountStakingInfo.address)
    self.name = accountStakingInfo.name
    self.totalAmount = accountStakingInfo.total_amount
    self.implementation = StackingPoolInfo.Implementation(
      implemenetationType: accountStakingInfo.implementation,
      implementation: implementations[accountStakingInfo.implementation.rawValue]
    )
    self.apy = Decimal(accountStakingInfo.apy)
    self.minStake = accountStakingInfo.min_stake
    self.cycleStart = TimeInterval(accountStakingInfo.cycle_start)
    self.cycleEnd = TimeInterval(accountStakingInfo.cycle_end)
    self.isVerified = accountStakingInfo.verified
    self.currentNominators = Int64(accountStakingInfo.current_nominators)
    self.maxNominators = Int64(accountStakingInfo.max_nominators)
    if let liquid_jetton_master = accountStakingInfo.liquid_jetton_master {
      self.liquidJettonMaster = try Address.parse(liquid_jetton_master)
    } else {
      self.liquidJettonMaster = nil
    }
    self.nominatorsStake = accountStakingInfo.nominators_stake
    self.validatorStake = accountStakingInfo.validator_stake
    if let cycle_length = accountStakingInfo.cycle_length {
      self.cycleLength = TimeInterval(cycle_length)
    } else {
      self.cycleLength = nil
    }
  }
}

extension StackingPoolInfo.Implementation {
  init(implemenetationType: Components.Schemas.PoolImplementationType,
       implementation: Components.Schemas.PoolImplementation?) {
    switch implemenetationType {
    case .whales:
      self.type = .whales
    case .tf:
      self.type = .tf
    case .liquidTF:
      self.type = .liquidTF
    }
    
    self.name = implementation?.name ?? ""
    self.description = implementation?.description ?? ""
    self.urlString = implementation?.url ?? ""
    self.socials = implementation?.socials ?? []
  }
}
