import Foundation
import BigInt

public struct BuySellModel {
  public enum Operation: Hashable {
    case buy
    case sell
  }
  
  public struct Token {
    public let symbol: String
    public let title: String
    public let fractionDigits: Int
    
    public init(symbol: String, title: String, fractionDigits: Int) {
      self.symbol = symbol
      self.title = title
      self.fractionDigits = fractionDigits
    }
  }
  
  public var operation: Operation
  public var buySellItem: BuySellItem
  public var minimumTokenAmount: BigUInt
  
  public var token: Token {
    buySellItem.tokenItem.token
  }
  public var tokenAmount: BigUInt {
    buySellItem.tokenItem.amount
  }
  
  public init(operation: Operation,
              token: Token,
              tokenAmount: BigUInt,
              minimumTokenAmount: BigUInt) {
    self.operation = operation
    self.minimumTokenAmount = minimumTokenAmount
    self.buySellItem = BuySellItem(
      input: .token,
      tokenItem: BuySellItem.Token(amount: tokenAmount, amountString: "", token: token),
      fiatItem: BuySellItem.Fiat(amount: 0, amountString: "", currency: .USD)
    )
  }
}

extension BuySellModel {
  public init(operation: Operation,
              token: Token,
              tokenAmountUInt: UInt64,
              minimumTokenAmountUInt: UInt64) {
    let tokenAmount = BigUInt.createBigUInt(from: tokenAmountUInt, fractionDigits: token.fractionDigits)
    let minimumTokenAmount = BigUInt.createBigUInt(from: minimumTokenAmountUInt, fractionDigits: token.fractionDigits)
    self.init(operation: operation, token: token, tokenAmount: tokenAmount, minimumTokenAmount: minimumTokenAmount)
  }
}

extension BuySellModel {
  public static func buyTon(initialAmount: UInt64, minAmount: UInt64) -> BuySellModel {
    BuySellModel(
      operation: .buy,
      token: .ton,
      tokenAmountUInt: initialAmount,
      minimumTokenAmountUInt: minAmount
    )
  }
  
  public static func sellTon(initialAmount: UInt64, minAmount: UInt64) -> BuySellModel {
    BuySellModel(
      operation: .sell,
      token: .ton,
      tokenAmountUInt: initialAmount,
      minimumTokenAmountUInt: minAmount
    )
  }
}

extension BuySellModel.Token {
  public static let ton = BuySellModel.Token(
    symbol: TonInfo.symbol,
    title: TonInfo.name,
    fractionDigits: TonInfo.fractionDigits
  )
}

private extension BigUInt {
  static func createBigUInt(from uintValue: UInt64, fractionDigits: Int) -> BigUInt {
    let string = "\(uintValue)\(String(repeating: "0", count: fractionDigits))"
    return BigUInt(stringLiteral: string)
  }
}
