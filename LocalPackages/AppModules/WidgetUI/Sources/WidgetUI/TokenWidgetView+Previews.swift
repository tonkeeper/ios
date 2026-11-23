import SwiftUI
import TKUIKit
import WidgetKit

extension TokenWidgetState {
    static let preview = TokenWidgetState(
        symbol: "GRAM",
        icon: UIImage.TKUIKit.Icons.Size44.currencyTon,
        price: "$1.22",
        change: WidgetChange(text: "\u{2212}1.79%", isDown: true),
        fiatChange: WidgetChange(text: "\u{2212}$0.02", isDown: true),
        period: "24h",
        updatedAt: WidgetPreviewData.updatedAt,
        chart: WidgetPreviewData.chart(from: 1.30, to: 1.22)
    )
}

@available(iOS 17.0, *)
#Preview("Price small", traits: .fixedLayout(width: 164, height: 164)) {
    TokenWidgetView(state: .preview, family: .systemSmall)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Chart medium", traits: .fixedLayout(width: 350, height: 164)) {
    TokenChartWidgetView(state: .preview, family: .systemMedium)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Chart small", traits: .fixedLayout(width: 164, height: 164)) {
    TokenChartWidgetView(state: .preview, family: .systemSmall)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Lock Screen", traits: .fixedLayout(width: 360, height: 180)) {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            TokenChartWidgetView(state: .preview, family: .accessoryRectangular)
                .frame(width: 160, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            TokenWidgetView(state: .preview, family: .accessoryCircular)
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        }
        TokenWidgetView(state: .preview, family: .accessoryRectangular)
            .frame(width: 160, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .lockWidgetPreview()
}
