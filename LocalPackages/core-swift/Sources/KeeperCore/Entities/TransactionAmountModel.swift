import Foundation
import BigInt

public enum TransactionMode: CaseIterable {
  case buy
  case sell
}

public struct TransactionAmountModel {
  let mode: TransactionMode
  let amount: BigUInt
  
  public init(mode: TransactionMode, amount: BigUInt) {
    self.mode = mode
    self.amount = amount
  }
}
