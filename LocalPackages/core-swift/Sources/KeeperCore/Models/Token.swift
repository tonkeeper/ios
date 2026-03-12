import Foundation
import TronSwift

public enum Token: Equatable, Hashable {
    case ton(TonToken)
    case usdtTron

    public var fractionDigits: Int {
        switch self {
        case let .ton(tonToken): tonToken.fractionDigits
        case .usdtTron: TronSwift.USDT.fractionDigits
        }
    }

    public var symbol: String {
        switch self {
        case let .ton(tonToken): tonToken.symbol
        case .usdtTron: TronSwift.USDT.symbol
        }
    }

    public var chartIdentifier: String {
        switch self {
        case let .ton(tonToken): tonToken.identifier
        case .usdtTron: JettonMasterAddress.tonUSDT.toRaw()
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
        case .usdtTron: "usdt_trc20"
        }
    }
}
