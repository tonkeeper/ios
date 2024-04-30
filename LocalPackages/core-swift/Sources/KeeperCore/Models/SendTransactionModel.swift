import Foundation
import TonSwift
import TonAPI
import BigInt

struct SendTransactionModel {
  
  let fee: Int64
  let extra: Int64
  
  init(fee: Int64, extra: Int64) {
    self.fee = fee
    self.extra = extra
  }
   
  init(accountEvent: Components.Schemas.AccountEvent,
       risk: Components.Schemas.Risk,
       transaction: Components.Schemas.Transaction) {
    self.fee = transaction.total_fees
    self.extra = accountEvent.extra
  }
}
