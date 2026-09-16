import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

extension TradeAssetDetailsViewModel {
    enum HeaderSubtitleViewData {
        case tokenizedAsset(TokenizedAssetInfoKind)
        case unverifiedAsset
        case chainInfo(MultichainChain)

        init?(assetInfo: TradingAssetInfo, isMultichain: Bool) {
            if isMultichain {
                let chain = AssetIdComponents(assetId: assetInfo.assetId)
                    .map(\.chain)
                    .flatMap(MultichainChain.init(assetIdChain:))
                if let chain {
                    self = .chainInfo(chain)
                } else {
                    return nil
                }
            } else {
                if assetInfo.isUnverified {
                    self = .unverifiedAsset
                } else if let kind = assetInfo.category.tokenizedAssetInfoKind {
                    self = .tokenizedAsset(kind)
                } else {
                    return nil
                }
            }
        }

        init?(preview: PreviewContext, isMultichain: Bool) {
            if isMultichain {
                let chain = AssetIdComponents(assetId: preview.assetID)
                    .map(\.chain)
                    .flatMap(MultichainChain.init(assetIdChain:))
                if let chain {
                    self = .chainInfo(chain)
                } else {
                    return nil
                }
            } else {
                if preview.isUnverified == true {
                    self = .unverifiedAsset
                } else if let kind = preview.assetCategory?.tokenizedAssetInfoKind {
                    self = .tokenizedAsset(kind)
                } else {
                    return nil
                }
            }
        }

        var color: TKColor {
            switch self {
            case .tokenizedAsset:
                .accentBlue
            case .unverifiedAsset:
                .accentOrange
            case .chainInfo:
                .textSecondary
            }
        }

        var title: String {
            switch self {
            case let .tokenizedAsset(kind):
                kind.badgeTitle
            case .unverifiedAsset:
                TKLocales.Token.unverified
            case let .chainInfo(chain):
                chain.displayTitle
            }
        }

        var hasInformationCircleIcon: Bool {
            switch self {
            case .tokenizedAsset, .unverifiedAsset:
                true
            case .chainInfo:
                false
            }
        }
    }
}
