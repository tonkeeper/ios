import Foundation
import TKLocalize

public enum Currency: String, Codable, CaseIterable {
  case TON = "TON"
  case JPY = "JPY"
  case USD = "USD"
  case EUR = "EUR"
  case RUB = "RUB"
  case AED = "AED"
  case KZT = "KZT"
  case UAH = "UAH"
  case GBP = "GBP"
  case CHF = "CHF"
  case CNY = "CNY"
  case KRW = "KRW"
  case IDR = "IDR"
  case INR = "INR"
  
  public init?(code: String) {
    self.init(rawValue: code)
  }
  
  public var code: String {
    self.rawValue
  }
  
  public var symbol: String {
    switch self {
    case .TON: return "TON"
    case .USD: return "$"
    case .JPY: return "¥"
    case .AED: return rawValue
    case .EUR: return "€"
    case .CHF: return "₣"
    case .CNY: return "¥"
    case .GBP: return "£"
    case .IDR: return "Rp"
    case .INR: return "₹"
    case .KRW: return "₩"
    case .KZT: return "₸"
    case .RUB: return "₽"
    case .UAH: return "₴"
    }
  }
  
  public var title: String {
    switch self {
    case .TON: return "Toncoin"
    case .USD: return TKLocales.Currency.Items.usd
    case .JPY: return TKLocales.Currency.Items.jpy
    case .AED: return TKLocales.Currency.Items.aed
    case .EUR: return TKLocales.Currency.Items.eur
    case .CHF: return TKLocales.Currency.Items.chf
    case .CNY: return TKLocales.Currency.Items.cny
    case .GBP: return TKLocales.Currency.Items.gbp
    case .IDR: return TKLocales.Currency.Items.idr
    case .INR: return TKLocales.Currency.Items.inr
    case .KRW: return TKLocales.Currency.Items.krw
    case .KZT: return TKLocales.Currency.Items.kzt
    case .RUB: return TKLocales.Currency.Items.rub
    case .UAH: return TKLocales.Currency.Items.uah
    }
  }
  
  public var symbolOnLeft: Bool {
    switch self {
    case .EUR, .USD, .GBP: return true
    default: return false
    }
  }
  
  public static var defaultCurrency: Currency {
    .USD
  }
}
