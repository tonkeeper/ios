import KeeperCore
import TKLogging
import TKUIKit
import TronSwift
import UIKit

extension AssetIdResolver {
    static func tag(for assetId: String, multichainEnabled: Bool) -> String? {
        chain(for: assetId, multichainEnabled: multichainEnabled)?
            .assetIdResolverTag(multichainEnabled: multichainEnabled)
    }

    static func imageSource(
        for assetId: String,
        imageUrl: URL?,
        multichainEnabled: Bool
    ) -> AssetAvatarViewImageSource {
        switch TradingAssetToken(assetId: assetId) {
        case .ton:
            return .image(.TKUIKit.Icons.Size44.tonLogo, chainIcon: nil)
        // A legacy wallet has no catalog entry to carry a TRX image, unlike a multichain one.
        case .tronTrx where !multichainEnabled:
            return .image(.TKUIKit.Icons.Size44.trxChain, chainIcon: nil)
        default:
            return .url(
                imageUrl,
                chainIcon: AssetIdResolver.chainIcon(
                    for: assetId,
                    multichainEnabled: multichainEnabled
                )
            )
        }
    }

    static func tkImageSource(
        for assetId: String,
        imageUrl: URL?,
        multichainEnabled: Bool
    ) -> (image: TKImage, chainIcon: UIImage?) {
        switch imageSource(
            for: assetId,
            imageUrl: imageUrl,
            multichainEnabled: multichainEnabled
        ) {
        case let .url(url, chainIcon):
            return (.urlImage(url), chainIcon)
        case let .image(image, chainIcon):
            return (.image(image), chainIcon)
        case .shimmer:
            return (.image(nil), nil)
        }
    }

    static func chainIcon(for assetId: String, multichainEnabled: Bool) -> UIImage? {
        chain(for: assetId, multichainEnabled: multichainEnabled)?
            .tokenIcon20
    }

    static func chain(for assetId: String, multichainEnabled: Bool) -> MultichainChain? {
        if multichainEnabled {
            badgeChainMultichain(for: assetId)
        } else {
            badgeChainLegacy(for: assetId)
        }
    }

    private static func badgeChainLegacy(for assetId: String) -> MultichainChain? {
        guard let components = AssetIdComponents(assetId: assetId) else {
            return nil
        }

        switch components {
        case .coin:
            return nil
        case let .asset(chain, _, type, address):
            guard let multichainChain = MultichainChain(assetIdChain: chain) else {
                return nil
            }
            let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            switch (multichainChain, normalizedType, address) {
            case (.ton, "jetton", JettonMasterAddress.tonUSDT.toRaw()):
                return .ton
            case (.tron, "token", TronSwift.USDT.address.base58),
                 (.tron, "tokens", TronSwift.USDT.address.base58),
                 (.tron, "trc20", TronSwift.USDT.address.base58):
                return .tron
            default:
                return nil
            }
        }
    }

    private static func badgeChainMultichain(for assetId: String) -> MultichainChain? {
        MultichainChain.badgeChain(forAssetId: assetId)
    }

    static func tonPreviewContext(
        wallet: Wallet
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        previewContext(
            assetID: "ton/\(wallet.network.tradeAssetDetailsNetworkIdentifier)/coin",
            assetCategory: .tokens,
            title: TonInfo.name,
            imageURL: nil,
            symbol: TonInfo.symbol,
            isUnverified: false,
            isTrusted: false
        )
    }

    static func usdtTrc20PreviewContext(
        wallet: Wallet,
        walletTron _: WalletTron
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        previewContext(
            assetID: "tron/\(wallet.network.tradeAssetDetailsNetworkIdentifier)/trc20/\(TronSwift.USDT.address.base58)",
            assetCategory: .tokens,
            title: TronSwift.USDT.name,
            imageURL: nil,
            symbol: TronSwift.USDT.symbol,
            isUnverified: false,
            isTrusted: false
        )
    }

    static func trxPreviewContext(
        wallet: Wallet,
        walletTron _: WalletTron
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        previewContext(
            assetID: "tron/\(wallet.network.tradeAssetDetailsNetworkIdentifier)/coin",
            assetCategory: .tokens,
            title: TronSwift.TRX.name,
            imageURL: nil,
            symbol: TronSwift.TRX.symbol,
            isUnverified: false,
            isTrusted: false
        )
    }

    static func jettonPreviewContext(
        wallet: Wallet,
        jettonItem: JettonItem
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        previewContext(
            assetID: "ton/\(wallet.network.tradeAssetDetailsNetworkIdentifier)/jetton/\(jettonItem.jettonInfo.address.toRaw())",
            assetCategory: .tokens,
            title: jettonItem.jettonInfo.name,
            imageURL: jettonItem.jettonInfo.imageURL,
            symbol: jettonItem.jettonInfo.symbol,
            isUnverified: jettonItem.jettonInfo.isUnverified,
            isTrusted: false
        )
    }

    private static func previewContext(
        assetID: String,
        assetCategory: TradingAssetCategory?,
        title: String?,
        imageURL: URL?,
        symbol: String?,
        isUnverified: Bool,
        isTrusted: Bool
    ) -> TradeAssetDetailsViewModel.PreviewContext {
        .init(
            assetID: assetID,
            assetCategory: assetCategory,
            title: title,
            imageURL: imageURL,
            symbol: symbol,
            isUnverified: isUnverified,
            isTrusted: isTrusted
        )
    }
}

private extension MultichainChain {
    func assetIdResolverTag(multichainEnabled: Bool) -> String? {
        if multichainEnabled {
            badgeTitle
        } else {
            switch self {
            case .ton:
                TonInfo.symbol
            case .tron:
                TronSwift.USDT.tag
            default:
                nil
            }
        }
    }
}

private extension KeeperCore.Network {
    var tradeAssetDetailsNetworkIdentifier: String {
        switch self {
        case .mainnet:
            "mainnet"
        case .testnet:
            "testnet"
        }
    }
}
