import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Trade Services", traits: .fixedLayout(width: 390, height: 116)) {
    TradeServicesView(services: [
        .init(kind: .tokens, title: "Tokens", icon: .TKUIKit.Icons.Size28.tokens),
        .init(kind: .perps, title: "Perps", icon: .TKUIKit.Icons.Size28.perps),
        .init(kind: .stocks, title: "Stocks", icon: .TKUIKit.Icons.Size28.trade),
        .init(kind: .etfs, title: "ETFs", icon: .TKUIKit.Icons.Size28.etfs),
    ], onOpenService: { _ in })
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
