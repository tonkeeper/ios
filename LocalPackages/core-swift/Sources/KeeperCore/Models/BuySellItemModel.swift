import Foundation
import BigInt

public struct BuySellItemModel {
  public struct Button {
    public let title: String
    public let url: String?
  }
  
  public let id: String
  public let title: String
  public let description: String?
  public let token: String?
  public let iconURL: URL?
  public let actionButton: Button?
  public let infoButtons: [Button]
  public let actionURL: URL?
  public let rate: Decimal
  public let currency: Currency
  public let minTonBuyAmount: BigUInt?
  public let minTonSellAmount: BigUInt?
}
