import Foundation

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
    case .USD: return "United States Dollar"
    case .JPY: return "Japanese Yen"
    case .AED: return "United Arab Emirates Dirham"
    case .EUR: return "Euro"
    case .CHF: return "Swiss Franc"
    case .CNY: return "China Yuan"
    case .GBP: return "Great Britain Pound"
    case .IDR: return "Indonesian Rupiah"
    case .INR: return "Indian Rupee"
    case .KRW: return "South Korean Won"
    case .KZT: return "Kazakhstani Tenge"
    case .RUB: return "Russian Ruble"
    case .UAH: return "Ukrainian hryvnian"
    }
  }
  
  public var symbolOnLeft: Bool {
    switch self {
    case .EUR, .USD, .GBP: return true
    default: return false
    }
  }
}
