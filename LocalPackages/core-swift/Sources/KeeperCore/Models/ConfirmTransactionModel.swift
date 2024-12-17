import Foundation
import BigInt

public struct ConfirmTransactionModel {

  public typealias TransactionTokenInfo = (token: Token, availableBalance: BigUInt)
   public struct ConfirmModel {
     public let fee: Int64
     public let tonBalance: UInt64
     public let requiredAmount: Int64
     public let token: TransactionTokenInfo
   }

  public struct Risk {
    public let formattedTotal: String
    public let title: String
    public let caption: String
    public let isRisk: Bool
  }

  public let event: AccountEventModel
  public let formattedFee: String
  public let wallet: Wallet
  public let formattedRisk: Risk?
  public let confirmModel: ConfirmModel?
}
