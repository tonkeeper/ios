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
  public var token: Token
  public var tokenAmount: BigUInt
  public var minimumTokenAmount: BigUInt
  
  public init(operation: Operation, token: Token, tokenAmount: BigUInt, minimumInputAmount: BigUInt) {
    self.operation = operation
    self.token = token
    self.tokenAmount = tokenAmount
    self.minimumTokenAmount = minimumInputAmount
  }
}

extension BuySellModel {
  public init(operation: Operation, token: Token, tokenAmountUInt: UInt64, minimumInputAmountUInt: UInt64) {
    self.operation = operation
    self.token = token
    self.tokenAmount = .createBigUInt(from: tokenAmountUInt, fractionDigits: token.fractionDigits)
    self.minimumTokenAmount = .createBigUInt(from: minimumInputAmountUInt, fractionDigits: token.fractionDigits)
  }
}

extension BuySellModel {
  public static func buyTon(initialAmount: UInt64, minAmount: UInt64) -> BuySellModel {
    BuySellModel(
      operation: .buy,
      token: .ton,
      tokenAmountUInt: initialAmount,
      minimumInputAmountUInt: minAmount
    )
  }
  
  public static func sellTon(initialAmount: UInt64, minAmount: UInt64) -> BuySellModel {
    BuySellModel(
      operation: .sell,
      token: .ton,
      tokenAmountUInt: initialAmount,
      minimumInputAmountUInt: minAmount
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
