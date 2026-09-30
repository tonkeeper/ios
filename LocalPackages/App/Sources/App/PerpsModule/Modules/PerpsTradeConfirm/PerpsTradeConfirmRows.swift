import Foundation
import KeeperCore
import TKLocalize

extension PerpsTradeConfirmViewModel {
    static func makeOpenRows(context: PerpsConfirmContext, referencePrice: Double) -> [Row] {
        let intent = context.intent
        let review = context.review
        let symbol = review.symbol
        var rows: [Row] = []

        rows.append(usdtRow(id: .youPay, title: TKLocales.Perps.Confirm.youPay, usd: review.marginUsd))

        if let entryPrice = review.entryPrice, entryPrice > 0 {
            rows.append(Row(
                id: .entry,
                title: TKLocales.Perps.Confirm.entryPrice,
                value: PerpsFormatting.usd(entryPrice),
                subValue: "≈ 1 \(symbol)"
            ))
        } else {
            rows.append(Row(id: .entry, title: TKLocales.Perps.Confirm.entryPrice, value: TKLocales.Perps.Confirm.unavailable, subValue: nil))
        }

        rows.append(Row(id: .leverage, title: TKLocales.Perps.Confirm.leverage, value: PerpsFormatting.leverage(intent.leverage), subValue: nil))

        rows.append(liquidationRow(review: review))

        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: PerpsFormatting.usd(review.notionalUsd),
            subValue: review.baseSize > 0 ? "≈ \(PerpsFormatting.token(review.baseSize, symbol: symbol, decimals: context.sizeDecimals))" : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd))

        if let autoCloseRow = autoCloseRow(
            from: intent.autoClose,
            side: intent.side,
            referencePrice: referencePrice,
            liquidationPrice: review.liquidationPrice
        ) {
            rows.append(autoCloseRow)
        }

        return rows
    }

    static func makeCloseRows(review: PerpsCloseReview, sizeDecimals: Int) -> [Row] {
        var rows: [Row] = []

        rows.append(usdtRow(id: .position, title: TKLocales.Perps.Confirm.position, usd: review.marginUsd))

        rows.append(Row(
            id: .leverage,
            title: TKLocales.Perps.Confirm.leverage,
            value: review.leverage.map(PerpsFormatting.leverage) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: PerpsFormatting.usd(review.notionalUsd),
            subValue: review.baseSize > 0 ? "≈ \(PerpsFormatting.token(review.baseSize, symbol: review.symbol, decimals: sizeDecimals))" : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd))

        if let pnl = review.estimatedPnlUsd {
            rows.append(Row(
                id: .pnl,
                title: TKLocales.Perps.Confirm.pnl,
                value: PerpsFormatting.signedUsd(pnl),
                subValue: review.estimatedPnlPercent.map { PerpsFormatting.signedPercent($0) },
                tone: pnl >= 0 ? .positive : .negative
            ))
        } else {
            rows.append(Row(id: .pnl, title: TKLocales.Perps.Confirm.pnl, value: TKLocales.Perps.Confirm.unavailable, subValue: nil))
        }

        rows.append(Row(
            id: .youReceive,
            title: TKLocales.Perps.Confirm.youReceive,
            value: review.estimatedReceiveUsd.map(PerpsFormatting.usd) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: review.estimatedReceiveUsd.map { "≈ \(PerpsFormatting.token($0, symbol: "USDT", decimals: 2))" }
        ))

        return rows
    }

    static func makeSizeChangeRows(
        review: PerpsSizeChangeReview,
        autoClose: PerpsAutoClose?,
        sizeDecimals: Int,
        referencePrice: Double
    ) -> [Row] {
        var rows: [Row] = []

        rows.append(payOrCloseRow(isAdd: review.direction == .add, usd: review.marginDeltaUsd))

        rows.append(Row(
            id: .entry,
            title: TKLocales.Perps.Confirm.entryPrice,
            value: review.entryPrice.isChanged
                ? "\(PerpsFormatting.usd(review.entryPrice.old)) → \(PerpsFormatting.usd(review.entryPrice.new))"
                : PerpsFormatting.usd(review.entryPrice.old),
            subValue: "≈ 1 \(review.symbol)"
        ))

        rows.append(Row(
            id: .leverage,
            title: TKLocales.Perps.Confirm.leverage,
            value: review.leverage.map(PerpsFormatting.leverage) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        rows.append(Row(
            id: .liquidation,
            title: TKLocales.Perps.Confirm.liquidation,
            value: review.liquidationPrice.map(PerpsFormatting.usd) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        let baseDelta = abs(review.baseSize.new - review.baseSize.old)
        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: "\(PerpsFormatting.usd(review.notionalUsd.old)) → \(PerpsFormatting.usd(review.notionalUsd.new))",
            subValue: baseDelta > 0
                ? "\(review.direction == .add ? "+" : "−")\(PerpsFormatting.token(baseDelta, symbol: review.symbol, decimals: sizeDecimals))"
                : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd))

        if let autoCloseRow = autoCloseRow(
            from: autoClose,
            side: review.side,
            referencePrice: referencePrice,
            liquidationPrice: review.liquidationPrice
        ) {
            rows.append(autoCloseRow)
        }

        return rows
    }

    /// No Fee row: UpdateMargin carries no venue fee and the SDK review has no
    /// fee field — the design's Fee line has no honest number behind it.
    static func makeMarginChangeRows(review: PerpsMarginChangeReview) -> [Row] {
        var rows: [Row] = []

        rows.append(payOrCloseRow(isAdd: review.direction == .add, usd: review.amountUsd))

        let liquidationValue: String
        if let liquidation = review.liquidationPrice {
            liquidationValue = liquidation.isChanged
                ? "\(PerpsFormatting.usd(liquidation.old)) → \(PerpsFormatting.usd(liquidation.new))"
                : PerpsFormatting.usd(liquidation.old)
        } else {
            liquidationValue = TKLocales.Perps.Confirm.unavailable
        }
        rows.append(Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: liquidationValue, subValue: nil))

        return rows
    }

    private static func liquidationRow(review: PerpsOpenOrderReview) -> Row {
        guard let liquidationPrice = review.liquidationPrice else {
            return Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: TKLocales.Perps.Confirm.unavailable, subValue: nil)
        }
        return Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: PerpsFormatting.usd(liquidationPrice), subValue: nil)
    }

    private static func autoCloseRow(
        from autoClose: PerpsAutoClose?,
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?
    ) -> Row? {
        guard let autoClose, !autoClose.isEmpty else { return nil }
        let invalid = PerpsAutoCloseValidation.invalidLegs(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            autoClose: autoClose
        )
        var parts: [ValuePart] = []
        if let takeProfit = autoClose.takeProfit {
            parts.append(ValuePart(
                text: "\(TKLocales.Perps.OpenPosition.tp) \(PerpsFormatting.usd(takeProfit.triggerPrice))",
                tone: invalid.takeProfit ? .negative : .neutral
            ))
        }
        if let stopLoss = autoClose.stopLoss {
            if !parts.isEmpty {
                parts.append(ValuePart(text: " / ", tone: .tertiary))
            }
            parts.append(ValuePart(
                text: "\(TKLocales.Perps.OpenPosition.sl) \(PerpsFormatting.usd(stopLoss.triggerPrice))",
                tone: invalid.stopLoss ? .negative : .neutral
            ))
        }
        let value = parts.map(\.text).joined()
        return Row(
            id: .autoClose,
            title: TKLocales.Perps.Confirm.autoClose,
            value: value,
            valueParts: parts,
            subValue: nil,
            showsChevron: true
        )
    }

    private static func usdtRow(id: Row.Kind, title: String, usd: Double) -> Row {
        Row(
            id: id,
            title: title,
            value: PerpsFormatting.usd(usd),
            subValue: "≈ \(PerpsFormatting.token(usd, symbol: "USDT", decimals: 2))"
        )
    }

    private static func payOrCloseRow(isAdd: Bool, usd: Double) -> Row {
        usdtRow(
            id: isAdd ? .youPay : .youClose,
            title: isAdd ? TKLocales.Perps.Confirm.youPay : TKLocales.Perps.Confirm.youClose,
            usd: usd
        )
    }

    private static func feeRow(estimatedFeeUsd: Double?) -> Row {
        Row(
            id: .fee,
            title: TKLocales.Perps.Confirm.fee,
            value: estimatedFeeUsd.map(PerpsFormatting.usd) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: estimatedFeeUsd.map { "≈ \(PerpsFormatting.token($0, symbol: "USDT", decimals: 4))" }
        )
    }
}
