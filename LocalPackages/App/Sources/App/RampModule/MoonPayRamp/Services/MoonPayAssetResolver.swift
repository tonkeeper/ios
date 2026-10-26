import Foundation
import KeeperCore
import MoonPay
import TonSwift

/// Finds the MoonPay asset that is the same on-chain asset as ours, by chain and contract rather
/// than by ticker: a symbol such as USDT exists on several networks and MoonPay prices each one
/// under its own code.
enum MoonPayAssetResolver {
    static func match(_ details: MultichainAssetDetails, in assets: [MoonPayPlatformAsset]) -> MoonPayPlatformAsset? {
        guard let components = AssetIdComponents(assetId: details.assetId) else { return nil }
        let available = assets.filter(\.isAvailable)
        let chain = MultichainChain(assetIdChain: components.chain)
        let onChain = chain.map { chain in
            let names = networkCodes(for: chain)
            return available.filter { names.contains($0.network.lowercased()) }
        }
        switch components {
        case .coin:
            let natives = (onChain ?? available).filter(isNative)
            return natives.first { $0.code.caseInsensitiveCompare(details.symbol) == .orderedSame }
                ?? (onChain != nil && natives.count == 1 ? natives.first : nil)
        case let .asset(_, _, _, address):
            let wanted = normalized(address, chain: chain)
            // A known chain never falls back to another network: one address can be a different token
            // on each EVM chain.
            return (onChain ?? available).first { asset in
                asset.contractAddress.map { normalized($0, chain: chain) } == wanted
            }
        }
    }

    /// MoonPay marks a native token with no contract or with the zero address (ETH, TRX, ...).
    private static func isNative(_ asset: MoonPayPlatformAsset) -> Bool {
        guard let contract = asset.contractAddress else { return true }
        let digits = contract.lowercased().hasPrefix("0x") ? contract.dropFirst(2) : Substring(contract)
        return !digits.isEmpty && digits.allSatisfy { $0 == "0" }
    }

    /// MoonPay's `network` codes for each of our chains, compared as whole values: a substring
    /// match would also take in networks such as `ethereum_classic`.
    private static func networkCodes(for chain: MultichainChain) -> Set<String> {
        switch chain {
        case .ton: ["ton"]
        case .eth: ["ethereum"]
        case .base: ["base"]
        case .btc: ["bitcoin"]
        case .tron: ["tron"]
        case .arb: ["arbitrum", "arbitrum_one"]
        case .bsc: ["binance_smart_chain", "bnb_smart_chain", "bsc"]
        case .sol: ["solana"]
        case .polygon: ["polygon", "polygon_pos"]
        case .avax: ["avalanche", "avalanche_c_chain", "avax"]
        case .robinhood: ["robinhood"]
        }
    }

    private static func normalized(_ address: String, chain: MultichainChain?) -> String {
        if chain == .ton, let parsed = try? Address.parse(address) {
            return parsed.toRaw()
        }
        return address.lowercased()
    }
}
