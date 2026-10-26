import Foundation
import PerpsModels
import TKLocalize

extension PerpsTradeConfirmViewModel {
    static func makeOpenRows(
        context: PerpsConfirmContext,
        referencePrice: Double,
        format: PerpsFormatting
    ) -> [Row] {
        let intent = context.intent
        let review = context.review
        let symbol = review.symbol
        var rows: [Row] = []

        rows.append(usdtRow(id: .youPay, title: TKLocales.Perps.Confirm.youPay, usd: review.marginUsd, format: format))

        if let entryPrice = review.entryPrice, entryPrice > 0 {
            rows.append(Row(
                id: .entry,
                title: TKLocales.Perps.Confirm.entryPrice,
                value: format.usd(entryPrice),
                subValue: nil
            ))
        } else {
            rows.append(Row(id: .entry, title: TKLocales.Perps.Confirm.entryPrice, value: TKLocales.Perps.Confirm.unavailable, subValue: nil))
        }

        rows.append(Row(id: .leverage, title: TKLocales.Perps.Confirm.leverage, value: format.leverage(intent.leverage), subValue: nil))

        rows.append(liquidationRow(review: review, format: format))

        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: format.usd(review.notionalUsd),
            subValue: review.baseSize > 0 ? "≈ \(format.token(review.baseSize, symbol: symbol, decimals: context.sizeDecimals))" : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd, format: format))

        rows.append(autoCloseRow(
            from: intent.autoClose,
            side: intent.side,
            referencePrice: referencePrice,
            liquidationPrice: review.liquidationPrice,
            format: format
        ) ?? Row(
            id: .autoClose,
            title: TKLocales.Perps.Confirm.autoClose,
            value: TKLocales.Perps.OpenPosition.set,
            subValue: nil,
            tone: .accent,
            showsChevron: true
        ))

        return rows
    }

    static func makeCloseRows(review: PerpsCloseReview, sizeDecimals: Int, format: PerpsFormatting) -> [Row] {
        var rows: [Row] = []

        rows.append(usdtRow(id: .position, title: TKLocales.Perps.Confirm.position, usd: review.marginUsd, format: format))

        rows.append(Row(
            id: .leverage,
            title: TKLocales.Perps.Confirm.leverage,
            value: review.leverage.map { format.leverage($0) } ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: format.usd(review.notionalUsd),
            subValue: review.baseSize > 0 ? "≈ \(format.token(review.baseSize, symbol: review.symbol, decimals: sizeDecimals))" : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd, format: format))

        if let pnl = review.estimatedPnlUsd {
            rows.append(Row(
                id: .pnl,
                title: TKLocales.Perps.Confirm.pnl,
                value: format.signedUsd(pnl),
                subValue: review.estimatedPnlPercent.map { format.signedPercent($0) },
                tone: pnl >= 0 ? .positive : .negative
            ))
        } else {
            rows.append(Row(id: .pnl, title: TKLocales.Perps.Confirm.pnl, value: TKLocales.Perps.Confirm.unavailable, subValue: nil))
        }

        rows.append(Row(
            id: .youReceive,
            title: TKLocales.Perps.Confirm.youReceive,
            value: review.estimatedReceiveUsd.map { format.usd($0) } ?? TKLocales.Perps.Confirm.unavailable,
            subValue: review.estimatedReceiveUsd.map { "≈ \(format.token($0, symbol: "USDT", decimals: 2))" }
        ))

        return rows
    }

    static func makeSizeChangeRows(
        review: PerpsSizeChangeReview,
        autoClose: PerpsAutoClose?,
        sizeDecimals: Int,
        referencePrice: Double,
        format: PerpsFormatting
    ) -> [Row] {
        var rows: [Row] = []

        rows.append(payOrCloseRow(isAdd: review.direction == .add, usd: review.marginDeltaUsd, format: format))

        rows.append(Row(
            id: .entry,
            title: TKLocales.Perps.Confirm.entryPrice,
            value: changeText(review.entryPrice, format: format),
            subValue: nil
        ))

        rows.append(Row(
            id: .leverage,
            title: TKLocales.Perps.Confirm.leverage,
            value: review.leverage.map { format.leverage($0) } ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        rows.append(Row(
            id: .liquidation,
            title: TKLocales.Perps.Confirm.liquidation,
            value: review.liquidationPrice.map { changeText($0, format: format) } ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        let baseDelta = abs(review.baseSize.new - review.baseSize.old)
        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: "\(format.usd(review.notionalUsd.old)) → \(format.usd(review.notionalUsd.new))",
            subValue: baseDelta > 0
                ? "\(review.direction == .add ? "+" : "−")\(format.token(baseDelta, symbol: review.symbol, decimals: sizeDecimals))"
                : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd, format: format))

        if let autoCloseRow = autoCloseRow(
            from: autoClose,
            side: review.side,
            referencePrice: referencePrice,
            liquidationPrice: review.liquidationPrice?.new,
            format: format
        ) {
            rows.append(autoCloseRow)
        }

        return rows
    }

    /// No Fee row: UpdateMargin carries no venue fee and the SDK review has no
    /// fee field — the design's Fee line has no honest number behind it.
    static func makeMarginChangeRows(review: PerpsMarginChangeReview, format: PerpsFormatting) -> [Row] {
        var rows: [Row] = []

        rows.append(payOrCloseRow(isAdd: review.direction == .add, usd: review.amountUsd, format: format))

        rows.append(Row(
            id: .liquidation,
            title: TKLocales.Perps.Confirm.liquidation,
            value: review.liquidationPrice.map { changeText($0, format: format) } ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        return rows
    }

    private static func changeText(_ change: PerpsValueChange, format: PerpsFormatting) -> String {
        change.isChanged
            ? "\(format.usd(change.old)) → \(format.usd(change.new))"
            : format.usd(change.old)
    }

    private static func liquidationRow(review: PerpsOpenOrderReview, format: PerpsFormatting) -> Row {
        guard let liquidationPrice = review.liquidationPrice else {
            return Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: TKLocales.Perps.Confirm.unavailable, subValue: nil)
        }
        return Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: format.usd(liquidationPrice), subValue: nil)
    }

    private static func autoCloseRow(
        from autoClose: PerpsAutoClose?,
        side: PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?,
        format: PerpsFormatting
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
                text: unbreakable("\(TKLocales.Perps.OpenPosition.tp) \(format.usd(takeProfit.triggerPrice))"),
                tone: invalid.takeProfit ? .negative : .neutral
            ))
        }
        if let stopLoss = autoClose.stopLoss {
            if !parts.isEmpty {
                parts.append(ValuePart(text: " / ", tone: .tertiary))
            }
            parts.append(ValuePart(
                text: unbreakable("\(TKLocales.Perps.OpenPosition.sl) \(format.usd(stopLoss.triggerPrice))"),
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

    private static func unbreakable(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    private static func usdtRow(id: Row.Kind, title: String, usd: Double, format: PerpsFormatting) -> Row {
        Row(
            id: id,
            title: title,
            value: format.usd(usd),
            subValue: id == .youPay ? nil : "≈ \(format.token(usd, symbol: "USDT", decimals: 2))"
        )
    }

    private static func payOrCloseRow(isAdd: Bool, usd: Double, format: PerpsFormatting) -> Row {
        usdtRow(
            id: isAdd ? .youPay : .youClose,
            title: isAdd ? TKLocales.Perps.Confirm.youPay : TKLocales.Perps.Confirm.youClose,
            usd: usd,
            format: format
        )
    }

    private static func feeRow(estimatedFeeUsd: Double?, format: PerpsFormatting) -> Row {
        Row(
            id: .fee,
            title: TKLocales.Perps.Confirm.fee,
            value: estimatedFeeUsd.map { format.usd($0) } ?? TKLocales.Perps.Confirm.unavailable,
            subValue: estimatedFeeUsd.map { "≈ \(format.token($0, symbol: "USD", decimals: 4))" }
        )
    }
}
