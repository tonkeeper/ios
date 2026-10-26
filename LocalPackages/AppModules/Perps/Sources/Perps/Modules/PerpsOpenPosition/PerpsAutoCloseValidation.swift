import PerpsModels
import TKLocalize

public enum PerpsAutoCloseValidation {
    public struct Warning: Equatable {
        public enum Leg: Equatable {
            case takeProfit
            case stopLoss
        }

        public let leg: Leg
        public let message: String

        public init(leg: Leg, message: String) {
            self.leg = leg
            self.message = message
        }
    }

    public struct InvalidLegs: Equatable {
        public var takeProfit: Bool
        public var stopLoss: Bool

        public init(takeProfit: Bool, stopLoss: Bool) {
            self.takeProfit = takeProfit
            self.stopLoss = stopLoss
        }

        public init(_ leg: PerpsTriggerOrderSummary.Kind) {
            self.init(takeProfit: leg == .takeProfit, stopLoss: leg == .stopLoss)
        }

        public var confirmStaleKind: ConfirmStaleKind? {
            switch (takeProfit, stopLoss) {
            case (true, true): return .autoClose
            case (true, false): return .takeProfit
            case (false, true): return .stopLoss
            case (false, false): return nil
            }
        }
    }

    /// Confirm-time alert when the live mark has invalidated one or both legs.
    public enum ConfirmStaleKind: Equatable {
        case takeProfit
        case stopLoss
        case autoClose
    }

    public static func warning(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        autoClose: PerpsAutoClose,
        format: PerpsFormatting
    ) -> Warning? {
        warning(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: autoClose.takeProfit?.triggerPrice,
            stopLossPrice: autoClose.stopLoss?.triggerPrice,
            format: format
        )
    }

    public static func warning(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        takeProfitPrice: Double?,
        stopLossPrice: Double?,
        format: PerpsFormatting
    ) -> Warning? {
        let invalid = invalidLegs(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: stopLossPrice
        )
        if invalid.takeProfit, let takeProfitPrice,
           let reason = takeProfitReason(side: side, referencePrice: referencePrice, price: takeProfitPrice)
        {
            return Warning(leg: .takeProfit, message: reason.message(format: format))
        }
        if invalid.stopLoss, let stopLossPrice,
           let reason = stopLossReason(
               side: side,
               referencePrice: referencePrice,
               liquidationPrice: liquidationPrice,
               price: stopLossPrice
           )
        {
            return Warning(leg: .stopLoss, message: reason.message(format: format))
        }
        return nil
    }

    public static func invalidLegs(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        autoClose: PerpsAutoClose
    ) -> InvalidLegs {
        invalidLegs(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: autoClose.takeProfit?.triggerPrice,
            stopLossPrice: autoClose.stopLoss?.triggerPrice
        )
    }

    public static func invalidLegs(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        takeProfitPrice: Double?,
        stopLossPrice: Double?
    ) -> InvalidLegs {
        guard referencePrice > 0 else {
            return InvalidLegs(takeProfit: false, stopLoss: false)
        }
        let takeProfitInvalid = takeProfitPrice.map {
            takeProfitReason(side: side, referencePrice: referencePrice, price: $0) != nil
        } ?? false
        let stopLossInvalid = stopLossPrice.map {
            stopLossReason(
                side: side,
                referencePrice: referencePrice,
                liquidationPrice: liquidationPrice,
                price: $0
            ) != nil
        } ?? false
        return InvalidLegs(takeProfit: takeProfitInvalid, stopLoss: stopLossInvalid)
    }

    public static func confirmStaleKind(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        autoClose: PerpsAutoClose
    ) -> ConfirmStaleKind? {
        invalidLegs(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            autoClose: autoClose
        ).confirmStaleKind
    }

    public static func stripping(_ autoClose: PerpsAutoClose, removing invalid: InvalidLegs) -> PerpsAutoClose {
        PerpsAutoClose(
            takeProfit: invalid.takeProfit ? nil : autoClose.takeProfit,
            stopLoss: invalid.stopLoss ? nil : autoClose.stopLoss
        )
    }

    @MainActor
    static func refusedLegs<Review>(
        _ autoClose: PerpsAutoClose,
        refused leg: PerpsTriggerOrderSummary.Kind,
        replan: (PerpsAutoClose) async -> Result<Review, PerpsTradingError>
    ) async -> InvalidLegs {
        let refused = InvalidLegs(leg)
        let rest = stripping(autoClose, removing: refused)
        guard !rest.isEmpty,
              case let .failure(.invalidAutoClose(other?)) = await replan(rest),
              other != leg
        else { return refused }
        return InvalidLegs(takeProfit: true, stopLoss: true)
    }

    /// Whether a leg is valid is a pure comparison; only the copy needs a formatter, so
    /// the two are kept apart and `invalidLegs` stays formatter-free.
    private enum Reason {
        case takeProfitMustBeAboveCurrent
        case takeProfitMustBeBelowCurrent
        case stopLossMustBeBelowCurrent
        case stopLossMustBeAboveCurrent
        case stopLossMustBeAboveLiquidation(Double)
        case stopLossMustBeBelowLiquidation(Double)

        func message(format: PerpsFormatting) -> String {
            switch self {
            case .takeProfitMustBeAboveCurrent:
                return TKLocales.Perps.OpenPosition.takeProfitMustBeAboveCurrentPrice
            case .takeProfitMustBeBelowCurrent:
                return TKLocales.Perps.OpenPosition.takeProfitMustBeBelowCurrentPrice
            case .stopLossMustBeBelowCurrent:
                return TKLocales.Perps.OpenPosition.stopLossMustBeBelowCurrentPrice
            case .stopLossMustBeAboveCurrent:
                return TKLocales.Perps.OpenPosition.stopLossMustBeAboveCurrentPrice
            case let .stopLossMustBeAboveLiquidation(price):
                return TKLocales.Perps.OpenPosition.stopLossMustBeAboveLiquidationPrice(format.usd(price))
            case let .stopLossMustBeBelowLiquidation(price):
                return TKLocales.Perps.OpenPosition.stopLossMustBeBelowLiquidationPrice(format.usd(price))
            }
        }
    }

    private static func takeProfitReason(
        side: PerpsTradeSide,
        referencePrice: Double,
        price: Double
    ) -> Reason? {
        switch side {
        case .long:
            return price > referencePrice ? nil : .takeProfitMustBeAboveCurrent
        case .short:
            return price < referencePrice ? nil : .takeProfitMustBeBelowCurrent
        }
    }

    private static func stopLossReason(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        price: Double
    ) -> Reason? {
        switch side {
        case .long:
            if price >= referencePrice {
                return .stopLossMustBeBelowCurrent
            }
            if let liquidationPrice, liquidationPrice > 0, price <= liquidationPrice {
                return .stopLossMustBeAboveLiquidation(liquidationPrice)
            }
        case .short:
            if price <= referencePrice {
                return .stopLossMustBeAboveCurrent
            }
            if let liquidationPrice, liquidationPrice > 0, price >= liquidationPrice {
                return .stopLossMustBeBelowLiquidation(liquidationPrice)
            }
        }
        return nil
    }
}
