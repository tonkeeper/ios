import TronSwift

public enum TronToken: String, Codable, Equatable, Hashable {
    case usdt
    case trx

    public var fractionDigits: Int {
        switch self {
        case .usdt:
            TronSwift.USDT.fractionDigits
        case .trx:
            TronSwift.TRX.fractionDigits
        }
    }

    public var symbol: String {
        switch self {
        case .usdt:
            TronSwift.USDT.symbol
        case .trx:
            TronSwift.TRX.symbol
        }
    }
}
