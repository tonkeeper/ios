import SwiftUI
import TKUIKit

private extension MoonPayProviderViewState {
    static let mock = MoonPayProviderViewState(
        rows: [
            .init(
                id: "moonpay",
                title: "MoonPay",
                subtitle: "Card, Apple Pay, PayPal",
                image: .image(.TKUIKit.Artwork.Providers.moonpay),
                isSelected: true
            ),
            .init(id: "mercuryo", title: "Mercuryo", subtitle: "Card, Apple Pay", image: .url(nil), isSelected: false),
            .init(
                id: "transak",
                title: "Transak",
                subtitle: "Card, Apple Pay, Bank transfer",
                image: .url(nil),
                isSelected: false
            ),
        ]
    )
}

@available(iOS 17.0, *)
#Preview("Provider", traits: .fixedLayout(width: 378, height: 252)) {
    MoonPayProviderView(state: .mock, onSelect: { _ in })
        .tkPreviewTheme(.deepBlue)
}
