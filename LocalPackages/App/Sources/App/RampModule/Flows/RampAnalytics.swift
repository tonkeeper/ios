import Foundation
import KeeperCore
import TKCore

struct RampOnrampContinueContext {
    let amount: Decimal
    let providerName: String
    let txId: String
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
        analyticsAssetId
    }

    var withdrawAnalyticsAssetIdentifier: String? {
        analyticsAssetId
    }

    private var analyticsAssetId: String? {
        canonicalAnalyticsAssetId(assetId: assetId, symbol: symbol, isTron: isTronNetwork)
    }
}

extension OnRampLayoutCryptoMethod {
    var depositAnalyticsAssetIdentifier: String? {
        analyticsAssetId
    }

    var withdrawAnalyticsAssetIdentifier: String? {
        analyticsAssetId
    }

    private var analyticsAssetId: String? {
        canonicalAnalyticsAssetId(assetId: assetId, symbol: symbol, isTron: isTronNetwork)
    }
}

extension Token {
    var depositAnalyticsReceiveNetwork: DepositViewReceiveTokens.Network {
        switch self {
        case .ton:
            return .ton
        case .tron:
            return .trc20
        }
    }
}

private func canonicalAnalyticsAssetId(assetId: String, symbol: String, isTron: Bool) -> String? {
    if AssetIdComponents(assetId: assetId) != nil {
        return assetId
    }
    return resolveCanonicalAnalyticsAssetIdentifier(symbol: symbol, isTron: isTron)
}

private func resolveCanonicalAnalyticsAssetIdentifier(symbol: String, isTron: Bool) -> String? {
    if isTron {
        switch symbol.lowercased() {
        case "usdt":
            return Token.tron(.usdt).assetId(network: .mainnet)
        default:
            return nil
        }
    } else {
        switch symbol.lowercased() {
        case "ton":
            return Token.ton(.ton).assetId(network: .mainnet)
        case "usdt":
            return "ton/mainnet/jetton/\(JettonMasterAddress.tonUSDT.toRaw())"
        default:
            return nil
        }
    }
}
