import Foundation
import TonAPI

public struct ConfirmTransactionModel {
  public let event: AccountEventModel
  public let fee: String
  public let wallet: Wallet
  public let risk: Risk
}
