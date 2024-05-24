import Foundation
import BigInt

public enum TransactionMode: CaseIterable {
  case buy
  case sell
}

public struct TransactionAmountModel {
  public let mode: TransactionMode
  public let amount: BigUInt
  
  public init(mode: TransactionMode, amount: BigUInt) {
    self.mode = mode
    self.amount = amount
  }
}
