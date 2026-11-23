import SwiftUI
import TKUIKit

private let previewPositions = [
    PerpsPositionRowItem(
        id: 1,
        symbol: "BTC",
        iconURL: nil,
        leverageText: "27⨯",
        sideText: "LONG",
        isLong: true,
        valueText: "$540.00",
        pnlText: "+ $18.24",
        isPnlPositive: true
    ),
    PerpsPositionRowItem(
        id: 2,
        symbol: "ETH",
        iconURL: nil,
        leverageText: "10⨯",
        sideText: "SHORT",
        isLong: false,
        valueText: "$212.40",
        pnlText: "− $6.03",
        isPnlPositive: false
    ),
]

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        PerpsOpenPositionsCard(
            total: PerpsPositionsTotal(
                amountText: "$752.40",
                pnlText: "+ $12.21",
                pnlPercentText: "+1.65%",
                isPnlPositive: true
            ),
            positions: previewPositions,
            onSelect: { _ in }
        )
        PerpsOpenPositionsCard(positions: [previewPositions[1]], onSelect: { _ in })
    }
    .padding()
    .frame(width: 390)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("More positions", traits: .sizeThatFitsLayout) {
    PerpsOpenPositionsCard(
        positions: previewPositions + [
            PerpsPositionRowItem(
                id: 3,
                symbol: "SOL",
                iconURL: nil,
                leverageText: "10⨯",
                sideText: "LONG",
                isLong: true,
                valueText: "$54.30",
                pnlText: "− $2.14",
                isPnlPositive: false
            ),
        ],
        more: PerpsMorePositions(iconURLs: [nil, nil]),
        onSelect: { _ in }
    )
    .padding()
    .frame(width: 390)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
