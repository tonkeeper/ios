import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Candles", traits: .fixedLayout(width: 390, height: 68)) {
    PerpsChartPeriodRow(timeframe: .h1, mode: .candle, onSelectTimeframe: { _ in }, onSelectMode: { _ in })
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Line", traits: .fixedLayout(width: 390, height: 68)) {
    PerpsChartPeriodRow(timeframe: .h1, mode: .line, onSelectTimeframe: { _ in }, onSelectMode: { _ in })
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
