import BigInt
import Foundation
import KeeperCore

final class MultichainSendAssetResolver {
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    private let assetDetailsService: TradingAssetDetailsService

    init(
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        assetDetailsService: TradingAssetDetailsService
    ) {
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
        self.assetDetailsService = assetDetailsService
    }

    func resolveAsset(
        for assetId: String,
        multichainState: MultichainWalletState
    ) async -> MultichainAsset? {
        if let asset = await multichainAssetBalanceProvider.loadAsset(
            for: assetId,
            multichainState: multichainState,
            includingHidden: true
        ) {
            return asset
        }

        guard let details = await tradingDetails(for: assetId) else {
            return nil
        }

        return MultichainAsset(
            asset: MultichainAssetDetails(assetInfo: details.assetInfo),
            price: MultichainAssetPrice.empty,
            balance: .zero,
            marketCap: [:]
        )
    }
}

private extension MultichainSendAssetResolver {
    func tradingDetails(for assetId: String) async -> TradingAssetDetails? {
        if let details = await assetDetailsService.assetDetails(for: assetId) {
            return details
        }

        do {
            return try await assetDetailsService.loadAssetDetails(id: assetId)
        } catch {
            return nil
        }
    }
}

private extension MultichainAssetDetails {
    init(assetInfo: TradingAssetInfo) {
        self.init(
            assetId: assetInfo.assetId,
            name: assetInfo.title,
            symbol: assetInfo.symbol,
            decimals: assetInfo.decimals,
            image: assetInfo.imageURL?.absoluteString ?? ""
        )
    }
}

private extension MultichainAssetPrice {
    static var empty: MultichainAssetPrice {
        MultichainAssetPrice(
            prices: [:],
            diff24h: [:],
            diff7d: [:],
            diff30d: [:]
        )
    }
}
