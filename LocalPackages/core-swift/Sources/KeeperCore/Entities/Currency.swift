import Foundation
import TKLocalize

public enum Currency: String, Codable, CaseIterable {
    case JPY
    case USD
    case EUR
    case RUB
    case AED
    case KZT
    case UAH
    case GBP
    case CHF
    case CNY
    case KRW
    case IDR
    case INR
    case UZS
    case BYN
    case BRL
    case TRY
    case NGN
    case THB
    case BDT
    case CAD
    case ILS
    case GEL
    case VND
    case AUD
    case ZAR
    case ARS
    case COP
    case ETB
    case KES
    case UGX
    case VES
    case TON
    case BTC

    public init?(code: String) {
        self.init(rawValue: code)
    }

    public var code: String {
        self.rawValue
    }

    public var symbol: String {
        switch self {
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
        case .UZS: return "sum"
        case .BYN: return "Br"
        case .BRL: return "R$"
        case .TRY: return "₺"
        case .NGN: return "₦"
        case .THB: return "฿"
        case .BDT: return "৳"
        case .CAD: return "C$"
        case .ILS: return "₪"
        case .GEL: return "₾"
        case .VND: return "đ"
        case .ZAR: return "R‎"
        case .ARS: return "$"
        case .COP: return "$"
        case .ETB: return "ብር"
        case .KES: return "KSh"
        case .UGX: return "USh"
        case .VES: return "Bs"
        case .TON: return "TON"
        case .BTC: return "₿"
        case .AUD: return "AU$"
        }
    }

    public var title: String {
        switch self {
        case .TON: return TKLocales.Currency.Items.ton
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
        case .UZS: return TKLocales.Currency.Items.uzs
        case .BYN: return TKLocales.Currency.Items.byn
        case .BRL: return TKLocales.Currency.Items.brl
        case .TRY: return TKLocales.Currency.Items.try
        case .NGN: return TKLocales.Currency.Items.ngn
        case .THB: return TKLocales.Currency.Items.thb
        case .BDT: return TKLocales.Currency.Items.bdt
        case .CAD: return TKLocales.Currency.Items.cad
        case .ILS: return TKLocales.Currency.Items.ils
        case .GEL: return TKLocales.Currency.Items.gel
        case .VND: return TKLocales.Currency.Items.vhd
        case .ZAR: return TKLocales.Currency.Items.zar
        case .ARS: return TKLocales.Currency.Items.ars
        case .COP: return TKLocales.Currency.Items.cop
        case .ETB: return TKLocales.Currency.Items.etb
        case .KES: return TKLocales.Currency.Items.kes
        case .UGX: return TKLocales.Currency.Items.ugx
        case .VES: return TKLocales.Currency.Items.ves
        case .BTC: return TKLocales.Currency.Items.btc
        case .AUD: return TKLocales.Currency.Items.aud
        }
    }

    public var symbolOnLeft: Bool {
        switch self {
        case .EUR, .USD, .GBP, .BDT, .CAD, .ILS, .AUD: return true
        default: return false
        }
    }

    public static var defaultCurrency: Currency {
        .USD
    }
}

extension Currency: CurrencyDisplayable {}

public struct RemoteCurrency: Codable {
    public enum CurrencyType: String {
        case fiat
        case crypto
    }

    public let code: String
    public let name: String
    public let image: String
    public let type: String

    public var currencyType: CurrencyType {
        CurrencyType(rawValue: type) ?? .fiat
    }

    public static var `default`: RemoteCurrency {
        RemoteCurrency(
            code: "USD",
            name: "US Dollar",
            image: "https://tonkeeper.com/assets/currencies/USD.png",
            type: "fiat"
        )
    }

    public var legacyCurrency: Currency {
        Currency(code: code) ?? .USD
    }
}
