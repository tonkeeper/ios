import Foundation

public enum TonToken: Equatable, Hashable {
    case ton
    case jetton(JettonItem)

    public var fractionDigits: Int {
        let digits: Int
        switch self {
        case .ton:
            digits = TonInfo.fractionDigits
        case let .jetton(jettonItem):
            digits = jettonItem.jettonInfo.fractionDigits
        }

        return digits
    }

    public var symbol: String {
        switch self {
        case .ton:
            return TonInfo.symbol
        case let .jetton(jettonItem):
            return jettonItem.jettonInfo.symbol ?? ""
        }
    }

    public var identifier: String {
        switch self {
        case .ton:
            return TonInfo.symbol
        case let .jetton(jettonItem):
            return jettonItem.jettonInfo.address.toRaw()
        }
    }

    public static func == (lhs: TonToken, rhs: TonToken) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
