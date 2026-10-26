import AppUI
import PerpsModels
import SwiftUI
import TKUIKit

private func previewEvent(_ kind: PerpsHistoryEvent.Kind, side: PerpsTradeSide, pnl: Double?, pnlPercent: Double?) -> PerpsHistoryEvent {
    PerpsHistoryEvent(
        id: "\(kind)",
        kind: kind,
        marketId: 1,
        symbol: "BTC",
        side: side,
        date: Date(timeIntervalSince1970: 1_770_220_800),
        leverage: 40,
        entryPrice: 66541.7,
        closePrice: pnl == nil ? nil : 66541.7,
        baseSize: 0.00781,
        usdSize: 540,
        margin: 20.5,
        pnl: pnl,
        pnlPercent: pnlPercent,
        fundingUsd: pnl == nil || kind == .reduced ? nil : -0.82,
        feeUsd: 0.144,
        fee: .init(value: 0.144, symbol: "USDC")
    )
}

private func previewDetails(_ event: PerpsHistoryEvent) -> some View {
    MultichainTransactionDetailsView(
        model: PerpsHistoryDetailsMapping.model(
            event: event,
            market: nil,
            format: .preview,
            onShare: event.isClosing ? {} : nil
        ),
        onOpenTransaction: { _, _ in },
        onCopy: { _ in }
    )
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(.backgroundPage)
}

#Preview("Long opened") {
    previewDetails(previewEvent(.opened, side: .long, pnl: nil, pnlPercent: nil))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Long increased") {
    previewDetails(previewEvent(.increased, side: .long, pnl: nil, pnlPercent: nil))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Short reduced") {
    previewDetails(previewEvent(.reduced, side: .short, pnl: 4.1, pnlPercent: 20.02))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Long closed") {
    previewDetails(previewEvent(.closed, side: .long, pnl: 10.25, pnlPercent: 10.01))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Short liquidated") {
    previewDetails(previewEvent(.liquidated, side: .short, pnl: -5.16, pnlPercent: -10.01))
        .tkPreviewTheme(.deepBlue)
}

#Preview("TP executed") {
    previewDetails(previewEvent(.takeProfit, side: .short, pnl: 10.25, pnlPercent: 10.01))
        .tkPreviewTheme(.deepBlue)
}

#Preview("SL executed") {
    previewDetails(previewEvent(.stopLoss, side: .short, pnl: -1.25, pnlPercent: -1.01))
        .tkPreviewTheme(.deepBlue)
}
