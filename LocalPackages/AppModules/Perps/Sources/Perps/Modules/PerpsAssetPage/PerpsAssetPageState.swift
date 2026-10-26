import UIKit

public struct PerpsAssetPagePosition: Equatable {
    public let valueText: String
    public let isPending: Bool
    public let pnlText: String
    public let pnlPercentText: String?
    public let isPnlPositive: Bool
    public let isLong: Bool
    public let sideText: String
    public let leverageText: String?
    public let sizeUsdText: String
    public let sizeTokenText: String
    public let liquidationText: String
    public let liquidationDistanceText: String?
    public let markText: String
    public let entryText: String
    public let fundingText: String

    public init(
        valueText: String,
        isPending: Bool,
        pnlText: String,
        pnlPercentText: String?,
        isPnlPositive: Bool,
        isLong: Bool,
        sideText: String,
        leverageText: String?,
        sizeUsdText: String,
        sizeTokenText: String,
        liquidationText: String,
        liquidationDistanceText: String?,
        markText: String,
        entryText: String,
        fundingText: String
    ) {
        self.valueText = valueText
        self.isPending = isPending
        self.pnlText = pnlText
        self.pnlPercentText = pnlPercentText
        self.isPnlPositive = isPnlPositive
        self.isLong = isLong
        self.sideText = sideText
        self.leverageText = leverageText
        self.sizeUsdText = sizeUsdText
        self.sizeTokenText = sizeTokenText
        self.liquidationText = liquidationText
        self.liquidationDistanceText = liquidationDistanceText
        self.markText = markText
        self.entryText = entryText
        self.fundingText = fundingText
    }
}

public enum PerpsAssetPageAutoCloseAffordance: Equatable {
    case setAutoClose
    case setTakeProfit
    case setStopLoss
    case none
}

public struct PerpsAssetPageTriggerOrder: Equatable, Identifiable {
    public let id: String
    public let actionText: String
    public let kindText: String
    public let isTakeProfit: Bool
    public let priceText: String
    public let valueText: String?
    public let percentText: String?
    public let isPositive: Bool

    public init(
        id: String,
        actionText: String,
        kindText: String,
        isTakeProfit: Bool,
        priceText: String,
        valueText: String?,
        percentText: String?,
        isPositive: Bool
    ) {
        self.id = id
        self.actionText = actionText
        self.kindText = kindText
        self.isTakeProfit = isTakeProfit
        self.priceText = priceText
        self.valueText = valueText
        self.percentText = percentText
        self.isPositive = isPositive
    }
}

public struct PerpsAssetPageLimitOrder: Equatable, Identifiable {
    public let id: String
    public let orderIndex: Int64
    public let limitPriceText: String
    public let captionText: String
    public let sideText: String
    public let isLong: Bool

    public init(
        id: String,
        orderIndex: Int64,
        limitPriceText: String,
        captionText: String,
        sideText: String,
        isLong: Bool
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.limitPriceText = limitPriceText
        self.captionText = captionText
        self.sideText = sideText
        self.isLong = isLong
    }
}

public struct PerpsAssetPageActivityRow: Equatable, Identifiable {
    public enum AmountStyle: Equatable {
        case primary
        case positive
        case negative
    }

    public let id: String
    public let icon: UIImage
    public let title: String
    public let subtitle: String
    public let dateText: String
    public let amountText: String?
    public let amountStyle: AmountStyle

    public init(
        id: String,
        icon: UIImage,
        title: String,
        subtitle: String,
        dateText: String,
        amountText: String?,
        amountStyle: AmountStyle
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.dateText = dateText
        self.amountText = amountText
        self.amountStyle = amountStyle
    }
}

public enum PerpsAssetPageActions: Equatable {
    case longShort(enabled: Bool)
    case editCashOut(editEnabled: Bool, cashOutEnabled: Bool)
    case editCancelLimitOrder(orderIndex: Int64, enabled: Bool)
    case hidden
}

public struct PerpsAssetPageReady: Equatable {
    public let title: String
    public let symbol: String
    public let iconLetter: String
    public let iconURL: URL?
    public let priceText: String
    public let changePercentText: String
    public let changeAmountText: String
    public let isChangePositive: Bool
    public let volumeText: String
    public let openInterestText: String
    public let fundingText: String?
    public let about: String?
    public let position: PerpsAssetPagePosition?
    public let limitOrders: [PerpsAssetPageLimitOrder]
    public let orders: [PerpsAssetPageTriggerOrder]
    public let autoClose: PerpsAssetPageAutoCloseAffordance
    public let history: [PerpsAssetPageActivityRow]
    public let canAdjustMargin: Bool
    public let canEditAutoClose: Bool
    public let canCancelOrders: Bool
    public let isLimitOrderBusy: Bool
    public let actions: PerpsAssetPageActions

    public init(
        title: String,
        symbol: String,
        iconLetter: String,
        iconURL: URL?,
        priceText: String,
        changePercentText: String,
        changeAmountText: String,
        isChangePositive: Bool,
        volumeText: String,
        openInterestText: String,
        fundingText: String?,
        about: String?,
        position: PerpsAssetPagePosition?,
        limitOrders: [PerpsAssetPageLimitOrder],
        orders: [PerpsAssetPageTriggerOrder],
        autoClose: PerpsAssetPageAutoCloseAffordance,
        history: [PerpsAssetPageActivityRow],
        canAdjustMargin: Bool,
        canEditAutoClose: Bool,
        canCancelOrders: Bool,
        isLimitOrderBusy: Bool,
        actions: PerpsAssetPageActions
    ) {
        self.title = title
        self.symbol = symbol
        self.iconLetter = iconLetter
        self.iconURL = iconURL
        self.priceText = priceText
        self.changePercentText = changePercentText
        self.changeAmountText = changeAmountText
        self.isChangePositive = isChangePositive
        self.volumeText = volumeText
        self.openInterestText = openInterestText
        self.fundingText = fundingText
        self.about = about
        self.position = position
        self.limitOrders = limitOrders
        self.orders = orders
        self.autoClose = autoClose
        self.history = history
        self.canAdjustMargin = canAdjustMargin
        self.canEditAutoClose = canEditAutoClose
        self.canCancelOrders = canCancelOrders
        self.isLimitOrderBusy = isLimitOrderBusy
        self.actions = actions
    }
}

public enum PerpsAssetPageState: Equatable {
    case loading
    case ready(PerpsAssetPageReady)
    case failed
    case notFound

    public var ready: PerpsAssetPageReady? {
        if case let .ready(ready) = self { ready } else { nil }
    }
}

public enum PerpsAssetPageTradeToast: Equatable {
    case progress(String)
    case success(String)
    case failure(String)
}
