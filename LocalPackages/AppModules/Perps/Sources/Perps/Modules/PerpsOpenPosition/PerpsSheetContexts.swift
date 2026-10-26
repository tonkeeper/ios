import Foundation
import PerpsModels

public struct PerpsLeverageSheetContext {
    public let marketId: Int64
    public let side: PerpsTradeSide
    public let bounds: PerpsLeverageBounds
    public let current: Double

    public init(marketId: Int64, side: PerpsTradeSide, bounds: PerpsLeverageBounds, current: Double) {
        self.marketId = marketId
        self.side = side
        self.bounds = bounds
        self.current = current
    }
}

public struct PerpsAutoCloseSheetContext {
    public let marketId: Int64
    public let side: PerpsTradeSide
    public let entryPrice: Double
    public let referencePrice: Double
    public let leverage: Double
    /// The size the legs close, for the expected profit and loss.
    public let baseSize: Double
    public let liquidationPrice: Double?
    public let priceDecimals: Int
    public let draft: PerpsAutoClose?
    public let roiInput: PerpsAutoCloseROIInput
    public let livePriceMarketId: Int64?

    public init(
        marketId: Int64,
        side: PerpsTradeSide,
        entryPrice: Double,
        referencePrice: Double,
        leverage: Double,
        baseSize: Double,
        liquidationPrice: Double?,
        priceDecimals: Int,
        draft: PerpsAutoClose?,
        roiInput: PerpsAutoCloseROIInput = .none,
        livePriceMarketId: Int64? = nil
    ) {
        self.marketId = marketId
        self.side = side
        self.entryPrice = entryPrice
        self.referencePrice = referencePrice
        self.leverage = leverage
        self.baseSize = baseSize
        self.liquidationPrice = liquidationPrice
        self.priceDecimals = priceDecimals
        self.draft = draft
        self.roiInput = roiInput
        self.livePriceMarketId = livePriceMarketId
    }
}
