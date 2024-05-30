import Foundation

public struct WalletBalanceItemsModel {
  public let tonItems: [Item]
  public let jettonsItems: [Item]
  
  public init(tonItems: [Item], jettonsItems: [Item]) {
    self.tonItems = tonItems
    self.jettonsItems = jettonsItems
  }
}

public extension WalletBalanceItemsModel {
  struct Item {
    public let identifier: String
    public let token: Token
    public let image: TokenImage
    public let title: String
    public let price: String?
    public let rateDiff: String?
    public let amount: String?
    public let convertedAmount: String?
    public let verification: JettonInfo.Verification
    public let hasPrice: Bool

    public init(identifier: String, token: Token, image: TokenImage, title: String, price: String?, rateDiff: String?, amount: String?, convertedAmount: String?, verification: JettonInfo.Verification, hasPrice: Bool) {
      self.identifier = identifier
      self.token = token
      self.image = image
      self.title = title
      self.price = price
      self.rateDiff = rateDiff
      self.amount = amount
      self.convertedAmount = convertedAmount
      self.verification = verification
      self.hasPrice = hasPrice
    }
  }
}
