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
            tronToken.fractionDigits
        }
    }

    public var symbol: String {
        switch self {
        case let .ton(tonToken):
            tonToken.symbol
        case let .tron(tronToken):
            tronToken.symbol
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
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                JettonMasterAddress.tonUSDT.toRaw()
            case .trx:
                TronSwift.TRX.symbol
            }
        }
    }

    public func assetId(network: Network) -> String {
        switch self {
        case let .ton(tonToken):
            switch tonToken {
            case .ton:
                return AssetId.coin(chain: .ton, network: network)
            case let .jetton(jettonItem):
                return AssetId.jetton(address: jettonItem.jettonInfo.address, network: network)
            }
        case let .tron(tronToken):
            switch tronToken {
            case .trx:
                return AssetId.coin(chain: .tron, network: network)
            case .usdt:
                return AssetId.trc20(address: TronSwift.USDT.address.base58, network: network)
            }
        }
    }

    public var analyticsSymbol: String {
        switch self {
        case let .ton(tonToken):
            switch tonToken {
            case .ton: "ton_ton"
            case let .jetton(jettonItem):
                "\(jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name)_ton"
                    .normalizeTetherSymbol()
                    .lowercased()
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
