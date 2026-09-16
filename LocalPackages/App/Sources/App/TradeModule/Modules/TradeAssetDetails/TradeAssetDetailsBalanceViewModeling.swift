import BigInt
import Combine
import Foundation
import KeeperCore
import TKUIKit

struct TradeAssetDetailsBalanceSnapshot {
    let symbol: String
    let imageURL: URL?
    let amount: BigUInt
    let fractionDigits: Int
    let convertedAmount: Decimal?
    let tagText: String?
    let freshness: BalanceFreshness
}

enum TradeAssetDetailsVisibilityState: Equatable {
    case visible
    case hidden

    init(isHidden: Bool) {
        self = isHidden ? .hidden : .visible
    }
}

struct TradeAssetDetailsAssetVisibility {
    let state: TradeAssetDetailsVisibilityState
    let hasNonZeroBalance: Bool
    let asset: MultichainAsset?
}

extension TradeAssetDetailsAssetVisibility {
    init(asset: MultichainAsset) {
        self.init(
            state: TradeAssetDetailsVisibilityState(isHidden: asset.isHidden),
            hasNonZeroBalance: !asset.balance.isZero,
            asset: asset
        )
    }

    func applying(
        _ state: TradeAssetDetailsVisibilityState,
        wallet: Wallet?,
        provider: MultichainAssetBalanceProvider
    ) -> TradeAssetDetailsAssetVisibility {
        let updatedAsset = if let wallet, let asset {
            provider.applyVisibility(isHidden: state == .hidden, to: asset, wallet: wallet)
        } else {
            asset
        }
        return TradeAssetDetailsAssetVisibility(
            state: state,
            hasNonZeroBalance: hasNonZeroBalance,
            asset: updatedAsset
        )
    }
}

@MainActor
protocol TradeAssetDetailsBalanceViewModeling: AnyObject {
    var statePublisher: AnyPublisher<TradeAssetDetailsBalanceSnapshot?, Never> { get }
    var visibilityPublisher: AnyPublisher<TradeAssetDetailsAssetVisibility?, Never> { get }
    func scheduleUpdate()
    func didAppear()
    func didDisappear()
    func applyVisibility(_ state: TradeAssetDetailsVisibilityState)
}
