import BigInt
import Foundation
import KeeperCore
import TronSwift

enum SendV3Item {
    case ton(TonSendData.Item)
    case tron(TronSendData.Item)

    func setAmount(amount: BigUInt) -> SendV3Item {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(token, _):
                return .ton(.token(token, amount: amount))
            case .nft:
                return self
            }
        case let .tron(item):
            switch item {
            case .usdt:
                return .tron(.usdt(amount: amount))
            }
        }
    }

    var fractionalDigits: Int {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(token, _):
                return token.fractionDigits
            default:
                return 0
            }
        case let .tron(item):
            switch item {
            case .usdt:
                return TronSwift.USDT.fractionDigits
            }
        }
    }

    var amount: BigUInt {
        switch self {
        case let .ton(item):
            switch item {
            case let .token(_, amount):
                return amount
            default:
                return 0
            }
        case let .tron(item):
            switch item {
            case let .usdt(amount):
                return amount
            }
        }
    }

    var isSupportComment: Bool {
        switch self {
        case .ton:
            return true
        case .tron:
            return false
        }
    }
}

enum SendInput {
    case direct(item: SendV3Item)
    case withdraw(sourceAsset: OnRampLayoutToken, exchangeTo: OnRampLayoutCryptoMethod)
}
