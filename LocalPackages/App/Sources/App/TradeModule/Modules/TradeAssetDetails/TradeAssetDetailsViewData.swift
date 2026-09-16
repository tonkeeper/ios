import Foundation
import KeeperCore
import TKUIKit
import UIKit

struct TradeAssetDetailsHeaderViewData {
    let title: String
    let imageSource: AssetAvatarViewImageSource
    let subtitle: TradeAssetDetailsViewModel.HeaderSubtitleViewData?
    let showsVerificationCheckmark: Bool
    let earnText: String?
}

struct TradeAssetDetailsMetricViewData: Identifiable {
    let id: String
    let title: String
    let value: String
    let secondaryValue: String?
    let secondaryValuePositive: Bool
    let hint: String?
}

struct TradeAssetDetailsTradingActivityViewData {
    let volumeText: String
    let volumeChangeText: String?
    let volumeChangeColor: UIColor
    let volumeChangePositive: Bool
    let buyText: String
    let sellText: String
    let buyFraction: Double
    let attributionText: AttributedString
}

struct TradeAssetDetailsBalanceSectionViewData {
    let symbol: String
    let iconImageSource: AssetAvatarViewImageSource
    let amountText: String
    let convertedAmountText: String?
    let chainTag: String?
    let freshness: BalanceFreshness
}

struct TradeAssetDetailsLinkViewData: Identifiable {
    let id: String
    let title: String
    let kind: TradingAssetLinkKind
    let url: URL?
}

struct TradeAssetDetailsHistoryItemViewData: Identifiable {
    let id: String
    let icon: TKUIKit.TransactionCellContent.Icon
    let title: String
    let subtitle: String
    let amountText: String
    let amountStyle: TKUIKit.TransactionCellContent.AmountStyle
    let dateText: String
}

struct TradeAssetDetailsHistorySectionViewData {
    let items: [TradeAssetDetailsHistoryItemViewData]
}

struct TradeAssetDetailsMultichainHistorySectionViewData {
    let items: [MultichainHistoryActivityItem]
}

enum TradeAssetDetailsActionButton: Equatable {
    case send
    case receive
    case cashBuy
    case cashSell
}

enum TradeAssetDetailsActionBarState: Equatable {
    case none
    case buy
    case buySell

    init(supportsSwap: Bool, hasBalance: Bool) {
        guard supportsSwap else {
            self = .none
            return
        }
        self = hasBalance ? .buySell : .buy
    }
}

struct TradeAssetDetailsScreenViewData {
    let id: String
    let title: String
    let imageURL: URL?
    let priceText: String
    let changeText: String?
    let changeAmountText: String?
    let changeColor: UIColor
    let earnText: String?
    let balance: TradeAssetDetailsBalanceSectionViewData?
    let aboutParagraph: String
    let overview: [TradeAssetDetailsMetricViewData]
    let tradingActivity: TradeAssetDetailsTradingActivityViewData?
    let assetType: TradeAssetDetailsAssetTypeSectionKind?
    let tronFees: TradeAssetDetailsTronFeesViewData?
    let history: TradeAssetDetailsHistorySectionViewData?
    let multichainHistory: TradeAssetDetailsMultichainHistorySectionViewData?
    let links: [TradeAssetDetailsLinkViewData]
    let primaryActionTitle: String
    let actionBarState: TradeAssetDetailsActionBarState
    let actionButtons: [TradeAssetDetailsActionButton]
    let isSendAvailable: Bool
}
