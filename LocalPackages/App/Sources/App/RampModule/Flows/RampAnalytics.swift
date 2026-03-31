import Foundation
import KeeperCore
import TKCore

struct RampOnrampContinueContext {
    let amount: Decimal
    let providerName: String
    let txId: UUID
}

enum DepositAnalyticsSource {
    case walletScreen

    var depositOpen: DepositOpen.From {
        switch self {
        case .walletScreen:
            .walletScreen
        }
    }

    var depositClickReceiveTokens: DepositClickReceiveTokens.From {
        switch self {
        case .walletScreen:
            .walletScreen
        }
    }

    var depositViewReceiveTokens: DepositViewReceiveTokens.From {
        switch self {
        case .walletScreen:
            .walletScreen
        }
    }
}

enum WithdrawAnalyticsSource {
    case walletScreen

    var withdrawOpen: WithdrawOpen.From {
        switch self {
        case .walletScreen:
            .walletScreen
        }
    }

    var withdrawClickSell: WithdrawClickSell.From {
        switch self {
        case .walletScreen:
            .walletScreen
        }
    }

    var withdrawClickSendTokens: WithdrawClickSendTokens.From {
        switch self {
        case .walletScreen:
            .walletScreen
        }
    }
}

extension OnRampLayoutToken {
    var depositAnalyticsAssetIdentifier: String? {
        resolveAnalyticsAssetIdentifier(symbol: symbol, isTron: isTronNetwork)
    }

    var withdrawAnalyticsAssetIdentifier: String? {
        resolveAnalyticsAssetIdentifier(symbol: symbol, isTron: isTronNetwork)
    }
}

extension OnRampLayoutCryptoMethod {
    var depositAnalyticsAssetIdentifier: String? {
        resolveAnalyticsAssetIdentifier(symbol: symbol, isTron: isTronNetwork)
    }

    var withdrawAnalyticsAssetIdentifier: String? {
        resolveAnalyticsAssetIdentifier(symbol: symbol, isTron: isTronNetwork)
    }
}

private func resolveAnalyticsAssetIdentifier(symbol: String, isTron: Bool) -> String? {
    if isTron {
        switch symbol.lowercased() {
        case "usdt":
            return DepositClickBuy.BuyAsset.tronTrc20Usdt.rawValue
        default:
            return nil
        }
    } else {
        switch symbol.lowercased() {
        case "ton":
            return DepositClickBuy.BuyAsset.tonNativeTon.rawValue
        case "usdt":
            return DepositClickBuy.BuyAsset.tonJettonUsdt.rawValue
        default:
            return nil
        }
    }
}
