enum ChartAsset: Equatable {
    case legacy(token: String)
    case multichain(assetId: String)
}

extension ChartAsset {
    init(token: Token, wallet: Wallet) {
        self = wallet.isMultichain
            ? .multichain(assetId: token.assetId(network: wallet.network))
            : .legacy(token: token.chartIdentifier)
    }

    init?(assetId: String, wallet: Wallet) {
        if wallet.isMultichain {
            self = .multichain(assetId: assetId)
        } else if let token = AssetIdResolver.chartIdentifier(for: assetId) {
            self = .legacy(token: token)
        } else {
            return nil
        }
    }

    var isMultichain: Bool {
        switch self {
        case .legacy:
            false
        case .multichain:
            true
        }
    }
}

extension ChartAsset {
    var cacheToken: String {
        switch self {
        case let .legacy(token):
            "legacy/\(token)"
        case let .multichain(assetId):
            "multichain/\(assetId)"
        }
    }
}
