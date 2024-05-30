import Foundation
import BigInt

public struct BuySellItem {
  public enum Input {
    case token
    case fiat
    
    public var opposite: Input {
      switch self {
      case .token:
        return .fiat
      case .fiat:
        return .token
      }
    }
  }
  
  public protocol Item {
    var amount: BigUInt { get set }
    var amountString: String { get set }
    var fractionDigits: Int { get }
    var currencyCode: String { get }
    
    func updated(amount: BigUInt, amountString: String) -> Self
  }
  
  public struct Token: Item {
    public var amount: BigUInt
    public var amountString: String
    public var token: BuySellModel.Token
    public var fractionDigits: Int {
      token.fractionDigits
    }
    public var currencyCode: String {
      token.symbol
    }
    
    public init(amount: BigUInt, amountString: String, token: BuySellModel.Token) {
      self.amount = amount
      self.amountString = amountString
      self.token = token
    }
    
    public func updated(amount: BigUInt, amountString: String) -> BuySellItem.Token {
      Token(amount: amount, amountString: amountString, token: token)
    }
  }
  
  public struct Fiat: Item {
    public var amount: BigUInt
    public var amountString: String
    public var currency: Currency
    public var fractionDigits: Int {
      2
    }
    public var currencyCode: String {
      currency.code
    }
    
    public init(amount: BigUInt, amountString: String, currency: Currency) {
      self.amount = amount
      self.amountString = amountString
      self.currency = currency
    }
    
    public func updated(amount: BigUInt, amountString: String) -> BuySellItem.Fiat {
      Fiat(amount: amount, amountString: amountString, currency: currency)
    }
  }
  
  public var input: Input
  public var output: Input { input.opposite }
  public var tokenItem: Token
  public var fiatItem: Fiat
  
  public init(input: Input, tokenItem: Token, fiatItem: Fiat) {
    self.input = input
    self.tokenItem = tokenItem
    self.fiatItem = fiatItem
  }
  
  public func getItem(forInput input: Input) -> Item {
    switch input {
    case .token:
      return tokenItem
    case .fiat:
      return fiatItem
    }
  }
  
  public func getAmountString(forInput input: Input) -> String {
    return getItem(forInput: input).amountString
  }
}

extension BuySellItem.Token {
  public static let ton = BuySellItem.Token(amount: 0, amountString: "0", token: .ton)
}

extension BuySellItem.Fiat {
  public static let usd = BuySellItem.Fiat(amount: 0, amountString: "0", currency: .USD)
}
