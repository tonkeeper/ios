import Foundation
import TonSwift
import TonAPI
import BigInt

public struct SendTransactionModel {
  public let accountEvent: AccountEvent
  public let fee: Int64
  public let extra: Int64
  
  init(accountEvent: AccountEvent, fee: Int64, extra: Int64) {
    self.accountEvent = accountEvent
    self.fee = fee
    self.extra = extra
  }
   
  init(accountEvent: TonAPI.AccountEvent,
       risk: TonAPI.Risk,
       transaction: TonAPI.Transaction) throws {
    self.accountEvent = try AccountEvent(accountEvent: accountEvent)
    self.fee = transaction.totalFees
    self.extra = accountEvent.extra
  }
}
