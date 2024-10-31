import Foundation
import TonAPI

public struct ConfirmTransactionModel {
  public let event: AccountEventModel
  public let formattedFee: String
  public let fee: Int64
  public let wallet: Wallet
  public let risk: Risk
}
