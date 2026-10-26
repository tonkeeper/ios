import TronSwift

/// Decides which chain-specific fee/send engine backs a multichain transfer.
struct MultichainFeeEngineResolver {
    enum Engine: Equatable {
        case tronUSDT(tronAddress: String)
        case tonJetton(master: String)
        /// The chain's own fee from ChainKit, plus the methods the battery's relayer offers.
        case evm(chain: MultichainChain)
        case chainKit
    }

    struct Resolution: Equatable {
        let engine: Engine
        /// False while the relayer's config is not known: the engine then stands for one load only.
        let isSettled: Bool
    }

    private let relayedEVMChains: () async -> Set<MultichainChain>?

    init(relayedEVMChains: @escaping () async -> Set<MultichainChain>?) {
        self.relayedEVMChains = relayedEVMChains
    }

    func resolve(asset: MultichainAsset, wallet: Wallet) async -> Resolution {
        guard asset.asset.chain?.isEVM == true else {
            return Resolution(engine: resolve(asset: asset, wallet: wallet, relayedEVMChains: []), isSettled: true)
        }
        guard let relayedEVMChains = await relayedEVMChains() else {
            return Resolution(engine: .chainKit, isSettled: false)
        }
        return Resolution(
            engine: resolve(asset: asset, wallet: wallet, relayedEVMChains: relayedEVMChains),
            isSettled: true
        )
    }

    func resolve(
        asset: MultichainAsset,
        wallet: Wallet,
        relayedEVMChains: Set<MultichainChain>
    ) -> Engine {
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
        if let chain = asset.asset.chain, relayedEVMChains.contains(chain), state.address(for: chain) != nil {
            return .evm(chain: chain)
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
