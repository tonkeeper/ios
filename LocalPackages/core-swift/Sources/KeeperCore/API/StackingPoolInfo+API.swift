import Foundation
import TonSwift
import TonAPI

extension StackingPoolInfo {
  init(accountStakingInfo: Components.Schemas.PoolInfo) throws {
    self.address = try Address.parse(accountStakingInfo.address)
    self.name = accountStakingInfo.name
    self.totalAmount = accountStakingInfo.total_amount
    self.implementation = .init(implemenetation: accountStakingInfo.implementation)
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
  init(implemenetation: Components.Schemas.PoolImplementationType) {
    switch implemenetation {
    case .whales:
      self = .whales
    case .tf:
      self = .tf
    case .liquidTF:
      self = .liquidTF
    }
  }
}
