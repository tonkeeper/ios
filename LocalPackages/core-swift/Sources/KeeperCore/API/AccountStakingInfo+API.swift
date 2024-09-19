import Foundation
import TonSwift
import TonAPI

extension AccountStackingInfo {
  init(accountStakingInfo: TonAPI.AccountStakingInfo) throws {
    self.pool = try Address.parse(accountStakingInfo.pool)
    self.amount = accountStakingInfo.amount
    self.pendingDeposit = accountStakingInfo.pendingDeposit
    self.pendingWithdraw = accountStakingInfo.pendingWithdraw
    self.readyWithdraw = accountStakingInfo.readyWithdraw
  }
}
