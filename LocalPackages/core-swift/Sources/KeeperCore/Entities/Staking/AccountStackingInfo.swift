import Foundation
import TonSwift

public struct AccountStackingInfo: Codable, Equatable {
  public let pool: Address
  public let amount: Int64
  public let pendingDeposit: Int64
  public let pendingWithdraw: Int64
  public let readyWithdraw: Int64
  
  public init(pool: Address,
              amount: Int64,
              pendingDeposit: Int64,
              pendingWithdraw: Int64,
              readyWithdraw: Int64) {
    self.pool = pool
    self.amount = amount
    self.pendingDeposit = pendingDeposit
    self.pendingWithdraw = pendingWithdraw
    self.readyWithdraw = readyWithdraw
  }
}
