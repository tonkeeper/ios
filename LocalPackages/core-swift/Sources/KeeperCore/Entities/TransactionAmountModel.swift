import Foundation
import BigInt

public struct TransactionAmountModel {
  public let type: FiatMethodCategoryType
  public let amount: BigUInt
  
  public init(type: FiatMethodCategoryType, amount: BigUInt) {
    self.type = type
    self.amount = amount
  }
}
