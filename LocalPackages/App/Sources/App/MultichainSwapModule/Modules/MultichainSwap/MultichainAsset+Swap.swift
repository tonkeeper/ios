import Foundation
import KeeperCore
import TKUIKit

extension MultichainAsset {
    var swapDisplaySymbol: String {
        asset.symbol.isEmpty ? asset.name : asset.symbol
    }

    var swapAvatarSource: AssetAvatarViewImageSource {
        AssetIdResolver.imageSource(
            for: asset.assetId,
            imageUrl: URL(string: asset.image),
            multichainEnabled: true
        )
    }

    var swapNetworkTag: String? {
        AssetIdResolver.tag(
            for: asset.assetId,
            multichainEnabled: true
        )
    }

    func swapFormattedBalance(amountFormatter: AmountFormatter) -> String {
        amountFormatter.format(
            amount: balance,
            fractionDigits: asset.decimals,
            accessory: .none,
            style: .compact
        )
    }

    func swapAmountLine(amount: String) -> String {
        [amount, swapDisplaySymbol]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
    }
}
