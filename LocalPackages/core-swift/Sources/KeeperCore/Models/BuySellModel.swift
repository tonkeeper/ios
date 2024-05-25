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
  }
  
  public var operation: Operation
  public var token: Token
  public var inputAmount: BigUInt
  public var minimumInputAmount: BigUInt
  
  public init(operation: Operation, token: Token, inputAmount: BigUInt, minimumInputAmount: BigUInt) {
    self.operation = operation
    self.token = token
    self.inputAmount = inputAmount
    self.minimumInputAmount = minimumInputAmount
  }
}

extension BuySellModel {
  public init(operation: Operation, token: Token, inputAmountUInt: UInt64, minimumInputAmountUInt: UInt64) {
    self.operation = operation
    self.token = token
    self.inputAmount = .createBigUInt(from: inputAmountUInt, fractionDigits: token.fractionDigits)
    self.minimumInputAmount = .createBigUInt(from: minimumInputAmountUInt, fractionDigits: token.fractionDigits)
  }
}

extension BuySellModel {
  public static func buyTon(initialAmount: UInt64, minAmount: UInt64) -> BuySellModel {
    BuySellModel(
      operation: .buy,
      token: .ton,
      inputAmountUInt: initialAmount,
      minimumInputAmountUInt: minAmount
    )
  }
  
  public static func sellTon(initialAmount: UInt64, minAmount: UInt64) -> BuySellModel {
    BuySellModel(
      operation: .sell,
      token: .ton,
      inputAmountUInt: initialAmount,
      minimumInputAmountUInt: minAmount
    )
  }
}

private extension BuySellModel.Token {
  static let ton = BuySellModel.Token(
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
