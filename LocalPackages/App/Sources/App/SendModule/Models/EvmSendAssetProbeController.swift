import KeeperCore

enum EvmSendAssetResolution: Equatable {
    case send(asset: MultichainAsset, chain: MultichainChain)
    case picker(allowedChains: Set<MultichainChain>)
    case assetUnavailable
    case unsupported
}

/// Resolves the asset an ERC-681 link refers to. A link without `@chain_id` names a contract but
/// not a network, so the contract is probed across the wallet's EVM chains: a single hit is enough
/// to prefill the whole form, anything else falls back to a chain-filtered token picker.
final class EvmSendAssetProbeController {
    private let resolveAsset: (String, MultichainWalletState) async -> MultichainAsset?
    private let isTransferSupported: (MultichainAsset) -> Bool

    init(
        resolveAsset: @escaping (String, MultichainWalletState) async -> MultichainAsset?,
        isTransferSupported: @escaping (MultichainAsset) -> Bool
    ) {
        self.resolveAsset = resolveAsset
        self.isTransferSupported = isTransferSupported
    }

    func resolve(
        transfer: Deeplink.EvmTransferData,
        multichainState: MultichainWalletState
    ) async -> EvmSendAssetResolution {
        let walletChains = multichainState.addresses
            .map(\.chain)
            .filter(\.isEVM)
            .reduce(into: [MultichainChain]()) { chains, chain in
                guard !chains.contains(chain) else { return }
                chains.append(chain)
            }

        guard !walletChains.isEmpty else {
            return .unsupported
        }

        if let chain = transfer.chain {
            guard walletChains.contains(chain) else {
                return .unsupported
            }
            guard let asset = await sendableAsset(
                assetId: transfer.asset.assetId(chain: chain),
                multichainState: multichainState
            ) else {
                return .assetUnavailable
            }
            return .send(asset: asset, chain: chain)
        }

        // A native amount is denominated in whichever coin the user ends up picking, so there is
        // nothing to probe — only an ERC-20 contract identifies a specific asset.
        guard case let .erc20(contract) = transfer.asset else {
            return .picker(allowedChains: Set(walletChains))
        }

        let matches = await probe(
            contract: contract,
            chains: walletChains,
            multichainState: multichainState
        )

        switch matches.count {
        case 1:
            return .send(asset: matches[0].asset, chain: matches[0].chain)
        case 0:
            return .picker(allowedChains: Set(walletChains))
        default:
            return .picker(allowedChains: Set(matches.map(\.chain)))
        }
    }
}

private extension EvmSendAssetProbeController {
    struct Match {
        let asset: MultichainAsset
        let chain: MultichainChain
    }

    func probe(
        contract: String,
        chains: [MultichainChain],
        multichainState: MultichainWalletState
    ) async -> [Match] {
        var matches = [Match]()
        for chain in chains {
            guard let asset = await sendableAsset(
                assetId: Deeplink.EvmTransferData.Asset.erc20(contract: contract).assetId(chain: chain),
                multichainState: multichainState
            ) else {
                continue
            }
            matches.append(Match(asset: asset, chain: chain))
        }
        return matches
    }

    func sendableAsset(
        assetId: String,
        multichainState: MultichainWalletState
    ) async -> MultichainAsset? {
        guard let asset = await resolveAsset(assetId, multichainState),
              isTransferSupported(asset)
        else {
            return nil
        }
        return asset
    }
}

extension Deeplink.EvmTransferData.Asset {
    func assetId(chain: MultichainChain) -> String {
        switch self {
        case .native:
            chain.defaultSendAssetId
        case let .erc20(contract):
            "\(chain.rawValue)/mainnet/erc20/\(contract.lowercased())"
        }
    }
}
