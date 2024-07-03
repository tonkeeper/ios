import Foundation
import TonSwift
import TonAPI

extension AccountStackingInfo {
  init(accountStakingInfo: Components.Schemas.AccountStakingInfo) throws {
    self.pool = try Address.parse(accountStakingInfo.pool)
    self.amount = accountStakingInfo.amount
    self.pendingDeposit = accountStakingInfo.pending_deposit
    self.pendingWithdraw = accountStakingInfo.pending_withdraw
    self.readyWithdraw = accountStakingInfo.ready_withdraw
  }
}
