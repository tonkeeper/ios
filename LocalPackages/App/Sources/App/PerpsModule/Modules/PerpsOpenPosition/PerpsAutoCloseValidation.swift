import KeeperCore
import TKLocalize

enum PerpsAutoCloseValidation {
    struct Warning: Equatable {
        enum Leg: Equatable {
            case takeProfit
            case stopLoss
        }

        let leg: Leg
        let message: String
    }

    struct InvalidLegs: Equatable {
        var takeProfit: Bool
        var stopLoss: Bool

        var confirmStaleKind: ConfirmStaleKind? {
            switch (takeProfit, stopLoss) {
            case (true, true): return .autoClose
            case (true, false): return .takeProfit
            case (false, true): return .stopLoss
            case (false, false): return nil
            }
        }
    }

    /// Confirm-time alert when the live mark has invalidated one or both legs.
    enum ConfirmStaleKind: Equatable {
        case takeProfit
        case stopLoss
        case autoClose
    }

    static func warning(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        autoClose: PerpsAutoClose
    ) -> Warning? {
        warning(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: autoClose.takeProfit?.triggerPrice,
            stopLossPrice: autoClose.stopLoss?.triggerPrice
        )
    }

    static func warning(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        takeProfitPrice: Double?,
        stopLossPrice: Double?
    ) -> Warning? {
        let invalid = invalidLegs(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: stopLossPrice
        )
        if invalid.takeProfit, let takeProfitPrice,
           let warning = takeProfitWarning(side: side, referencePrice: referencePrice, price: takeProfitPrice)
        {
            return warning
        }
        if invalid.stopLoss, let stopLossPrice,
           let warning = stopLossWarning(
               side: side,
               referencePrice: referencePrice,
               liquidationPrice: liquidationPrice,
               price: stopLossPrice
           )
        {
            return warning
        }
        return nil
    }

    static func invalidLegs(
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

    static func invalidLegs(
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
            takeProfitWarning(side: side, referencePrice: referencePrice, price: $0) != nil
        } ?? false
        let stopLossInvalid = stopLossPrice.map {
            stopLossWarning(
                side: side,
                referencePrice: referencePrice,
                liquidationPrice: liquidationPrice,
                price: $0
            ) != nil
        } ?? false
        return InvalidLegs(takeProfit: takeProfitInvalid, stopLoss: stopLossInvalid)
    }

    static func confirmStaleKind(
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

    static func stripping(_ autoClose: PerpsAutoClose, removing invalid: InvalidLegs) -> PerpsAutoClose {
        PerpsAutoClose(
            takeProfit: invalid.takeProfit ? nil : autoClose.takeProfit,
            stopLoss: invalid.stopLoss ? nil : autoClose.stopLoss
        )
    }

    private static func takeProfitWarning(
        side: PerpsTradeSide,
        referencePrice: Double,
        price: Double
    ) -> Warning? {
        switch side {
        case .long:
            return price > referencePrice ? nil : Warning(
                leg: .takeProfit,
                message: TKLocales.Perps.OpenPosition.takeProfitMustBeAboveCurrentPrice
            )
        case .short:
            return price < referencePrice ? nil : Warning(
                leg: .takeProfit,
                message: TKLocales.Perps.OpenPosition.takeProfitMustBeBelowCurrentPrice
            )
        }
    }

    private static func stopLossWarning(
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        price: Double
    ) -> Warning? {
        switch side {
        case .long:
            if price >= referencePrice {
                return Warning(
                    leg: .stopLoss,
                    message: TKLocales.Perps.OpenPosition.stopLossMustBeBelowCurrentPrice
                )
            }
            if let liquidationPrice, liquidationPrice > 0, price <= liquidationPrice {
                return Warning(
                    leg: .stopLoss,
                    message: TKLocales.Perps.OpenPosition.stopLossMustBeAboveLiquidationPrice(PerpsFormatting.usd(liquidationPrice))
                )
            }
        case .short:
            if price <= referencePrice {
                return Warning(
                    leg: .stopLoss,
                    message: TKLocales.Perps.OpenPosition.stopLossMustBeAboveCurrentPrice
                )
            }
            if let liquidationPrice, liquidationPrice > 0, price >= liquidationPrice {
                return Warning(
                    leg: .stopLoss,
                    message: TKLocales.Perps.OpenPosition.stopLossMustBeBelowLiquidationPrice(PerpsFormatting.usd(liquidationPrice))
                )
            }
        }
        return nil
    }
}
