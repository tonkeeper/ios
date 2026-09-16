import TronSwift

/// What the relayer can be asked to move for a swap. Relaying a TON coin swap would have to reimburse
/// the relayer in the very asset being spent, and a TRC-20 other than USDT has no resource estimate to
/// price it with, so neither has a case here.
enum MultichainSwapRelayedAsset: Equatable {
    case tonJetton
    case tron(TronAsset)

    enum TronAsset: Equatable {
        case trx
        case usdt
    }

    var chain: MultichainChain {
        switch self {
        case .tonJetton:
            return .ton
        case .tron:
            return .tron
        }
    }

    init?(_ asset: MultichainAsset) {
        guard let components = AssetIdComponents(assetId: asset.asset.assetId) else {
            return nil
        }
        switch (asset.asset.chain, components) {
        case let (.ton, .asset(chain, _, type, _))
            where chain.lowercased() == "ton" && type.lowercased() == "jetton":
            self = .tonJetton
        case let (.tron, .coin(chain, _, _)) where chain.lowercased() == "tron":
            self = .tron(.trx)
        case let (.tron, .asset(chain, _, type, address))
            where chain.lowercased() == "tron"
            && type.lowercased() == "trc20"
            && address == TronSwift.USDT.address.base58:
            self = .tron(.usdt)
        default:
            return nil
        }
    }
}
