import Foundation
import KeeperCore
import TronSwift

enum BatteryPayWithOrder {
    enum Kind: Equatable {
        case tronUSDT
        case ethereumUSDT
        case tonUSDT
        case gram
        case appStore
        case other
    }

    /// USD₮ (on TRON, else Ethereum, else TON), GRAM and the App Store lead the list; the rest go under Other tokens.
    /// Without any of them, every method stays in the list.
    static func split<T>(_ items: [T], kind: (T) -> Kind) -> (featured: [T], other: [T]) {
        let kinds = items.map(kind)
        let usdt = kinds.firstIndex(of: .tronUSDT) ?? kinds.firstIndex(of: .ethereumUSDT) ?? kinds.firstIndex(of: .tonUSDT)
        let featured = [usdt, kinds.firstIndex(of: .gram), kinds.firstIndex(of: .appStore)].compactMap { $0 }
        guard !featured.isEmpty else { return (items, []) }
        return (featured.map { items[$0] }, items.indices.filter { !featured.contains($0) }.map { items[$0] })
    }

    static func isTronUSDT(assetId: String) -> Bool {
        guard case let .asset(chain, _, type, address) = AssetIdComponents(assetId: assetId) else { return false }
        return chain.lowercased() == "tron" && type.lowercased() == "trc20" && address == TronSwift.USDT.address.base58
    }

    static func isEthereumUSDT(assetId: String) -> Bool {
        AssetIdComponents.isSameAsset(assetId, "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7")
    }
}
