import KeeperCore
import TKUIKit
import UIKit

struct TradeItemsMapper {
    var multichainEnabled: Bool
    var signedAmountFormatter: AmountFormatter
}

extension TradeItemsMapper {
    static func previewContext(
        for asset: MultichainAsset
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        let details = asset.asset
        let trimmedImage = details.image.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL: URL? = {
            guard !trimmedImage.isEmpty else { return nil }
            return URL(string: trimmedImage)
        }()

        return TradeAssetDetailsViewModel.PreviewContext(
            assetID: details.assetId,
            title: details.name,
            imageURL: imageURL,
            symbol: details.symbol,
            isUnverified: !details.isVerified,
            isTrusted: details.isTrusted
        )
    }

    func assetViewData(
        from item: TradingMarketItem
    ) -> TradeShelfAssetViewData {
        assetViewData(
            id: item.id,
            symbol: item.symbol,
            title: item.name,
            category: item.category,
            imageURL: item.imageURL,
            change24hPercent: item.change24hPercent,
            isChangeLoading: false,
            isUnverified: item.isUnverified,
            isTrusted: item.isTrusted
        )
    }

    func applyingChange(
        to view: TradeShelfAssetViewData,
        change24hPercent: Decimal?,
        isUnverified: Bool? = nil,
        isTrusted: Bool? = nil
    ) -> TradeShelfAssetViewData {
        var view = view
        view.changeText = formatChange(change24hPercent)
        view.changeColor = changeColor(for: change24hPercent)
        view.isChangeLoading = false
        let preview = view.preview
        view.preview = TradeAssetDetailsViewModel.PreviewContext(
            assetID: preview.assetID,
            assetCategory: preview.assetCategory,
            title: preview.title,
            imageURL: preview.imageURL,
            symbol: preview.symbol,
            change24hPercent: change24hPercent,
            isUnverified: isUnverified ?? preview.isUnverified,
            isTrusted: isTrusted ?? preview.isTrusted
        )
        return view
    }

    func assetViewData(
        _ asset: TradingFavoriteAsset,
        isPriceDiffLoading: Bool
    ) -> TradeShelfAssetViewData {
        assetViewData(
            id: asset.id,
            symbol: asset.symbol,
            title: asset.symbol,
            category: nil,
            imageURL: asset.imageURL,
            change24hPercent: nil,
            isChangeLoading: isPriceDiffLoading,
            isUnverified: nil,
            isTrusted: nil
        )
    }

    func assetViewData(
        id: String,
        symbol: String,
        title: String?,
        category: TradingAssetCategory?,
        imageURL: URL?,
        change24hPercent: Decimal?,
        isChangeLoading: Bool,
        isUnverified: Bool?,
        isTrusted: Bool?
    ) -> TradeShelfAssetViewData {
        TradeShelfAssetViewData(
            id: id,
            symbol: symbol,
            iconImageSource: AssetIdResolver.imageSource(
                for: id,
                imageUrl: imageURL,
                multichainEnabled: multichainEnabled
            ),
            changeText: formatChange(change24hPercent),
            changeColor: changeColor(for: change24hPercent),
            isChangeLoading: isChangeLoading,
            preview: TradeAssetDetailsViewModel.PreviewContext(
                assetID: id,
                assetCategory: category,
                title: title,
                imageURL: imageURL,
                symbol: symbol,
                change24hPercent: change24hPercent,
                isUnverified: isUnverified,
                isTrusted: isTrusted
            )
        )
    }
}

extension TradeItemsMapper {
    func formatChange(_ change24hPercent: Decimal?) -> String? {
        guard let change24hPercent else {
            return nil
        }

        return signedAmountFormatter.format(
            decimal: change24hPercent,
            style: .percent
        )
    }

    func changeColor(for change24hPercent: Decimal?) -> TKColor {
        (change24hPercent ?? 0) < 0 ? .accentRed : .accentGreen
    }
}
