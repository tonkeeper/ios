import TronSwift

/// Decides which chain-specific fee/send engine backs a multichain transfer.
struct MultichainFeeEngineResolver {
    enum Engine: Equatable {
        case tronUSDT(tronAddress: String)
        case tonJetton(master: String)
        /// Toncoin through the TON send path, for a wallet that signs TON on a Ledger.
        case tonCoin
        /// The chain's own fee from ChainKit, plus the methods the battery's relayer offers: an EVM chain or Solana.
        case evm(chain: MultichainChain)
        case chainKit
    }

    struct Resolution: Equatable {
        let engine: Engine
        /// False while the relayer's config is not known: the engine then stands for one load only.
        let isSettled: Bool
    }

    private let relayedEVMChains: () async -> Set<MultichainChain>?
    /// A chain switched off here takes the ChainKit fee without waiting for the relayer's config, and is
    /// asked again on the next load: the remote config can switch it on meanwhile.
    private let relays: (MultichainChain) -> Bool

    init(
        relayedEVMChains: @escaping () async -> Set<MultichainChain>?,
        relays: @escaping (MultichainChain) -> Bool = { _ in true }
    ) {
        self.relayedEVMChains = relayedEVMChains
        self.relays = relays
    }

    func resolve(asset: MultichainAsset, wallet: Wallet) async -> Resolution {
        guard let chain = asset.asset.chain, chain.isEVM || chain == .sol else {
            return Resolution(engine: resolve(asset: asset, wallet: wallet, relayedEVMChains: []), isSettled: true)
        }
        guard relays(chain) else {
            return Resolution(engine: resolve(asset: asset, wallet: wallet, relayedEVMChains: []), isSettled: false)
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
        guard wallet.kind == .regular || wallet.kind == .ledger,
              wallet.network.isMainnet,
              case let .multichain(state) = wallet.multichain
        else {
            return .chainKit
        }

        if isTronUSDT(asset), let tronAddress = state.address(for: .tron) {
            return .tronUSDT(tronAddress: tronAddress)
        }

        // A Ledger signs TON in its TON app, through the engines a TON-only Ledger wallet uses. Its other sends go
        // through ChainKit: the relayer's EVM methods need a delegation the Ethereum app signs only to its own list of
        // contracts.
        if wallet.kind == .ledger {
            guard asset.asset.chain == .ton, state.address(for: .ton) != nil else {
                return .chainKit
            }
            return tonJettonMaster(asset).map { .tonJetton(master: $0) } ?? (asset.isNative ? .tonCoin : .chainKit)
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
