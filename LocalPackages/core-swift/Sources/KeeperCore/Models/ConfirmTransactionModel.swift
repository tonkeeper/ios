import Foundation

public struct ConfirmTransactionModel {

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
}
