import TronSwift

/// Decides which chain-specific fee/send engine backs a multichain transfer.
/// Pure and side-effect free so the routing can be unit-tested in isolation.
struct MultichainFeeEngineResolver {
    enum Engine: Equatable {
        case tronUSDT(tronAddress: String)
        case tonJetton(master: String)
        case chainKit
    }

    func resolve(asset: MultichainAsset, wallet: Wallet) -> Engine {
        guard wallet.kind == .regular,
              wallet.network.isMainnet,
              case let .multichain(state) = wallet.multichain
        else {
            return .chainKit
        }

        if isTronUSDT(asset), let tronAddress = state.address(for: .tron) {
            return .tronUSDT(tronAddress: tronAddress)
        }
        if let master = tonJettonMaster(asset), state.address(for: .ton) != nil {
            return .tonJetton(master: master)
        }
        return .chainKit
    }

    private func isTronUSDT(_ asset: MultichainAsset) -> Bool {
        guard asset.asset.chain == .tron,
              case let .asset(chain, _, type, address) = AssetIdComponents(assetId: asset.asset.assetId)
        else {
            return false
        }
        return chain.lowercased() == "tron"
            && type.lowercased() == "trc20"
            && address == TronSwift.USDT.address.base58
    }

    private func tonJettonMaster(_ asset: MultichainAsset) -> String? {
        guard asset.asset.chain == .ton,
              case let .asset(chain, _, type, address) = AssetIdComponents(assetId: asset.asset.assetId),
              chain.lowercased() == "ton",
              type.lowercased() == "jetton"
        else {
            return nil
        }
        return address
    }
}
