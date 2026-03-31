import Foundation
import TronSwift

public enum Token: Equatable, Hashable {
    case ton(TonToken)
    case tron(TronToken)

    public var fractionDigits: Int {
        switch self {
        case let .ton(tonToken):
            tonToken.fractionDigits
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                TronSwift.USDT.fractionDigits
            case .trx:
                TronSwift.TRX.fractionDigits
            }
        }
    }

    public var symbol: String {
        switch self {
        case let .ton(tonToken):
            tonToken.symbol
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                TronSwift.USDT.symbol
            case .trx:
                TronSwift.TRX.symbol
            }
        }
    }

    public var name: String {
        switch self {
        case let .ton(tonToken):
            tonToken.symbol
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                TronSwift.USDT.name
            case .trx:
                TronSwift.TRX.name
            }
        }
    }

    public var chartIdentifier: String {
        switch self {
        case let .ton(tonToken):
            tonToken.identifier
        case .tron:
            JettonMasterAddress.tonUSDT.toRaw()
        }
    }

    public var analyticsSymbol: String {
        switch self {
        case let .ton(tonToken):
            switch tonToken {
            case .ton: "ton_ton"
            case let .jetton(jettonItem):
                "\(jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name)_ton".replacingOccurrences(
                    of: "₮",
                    with: "t"
                ).lowercased()
            }
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                "usdt_trc20"
            case .trx:
                "trx"
            }
        }
    }
}
