import Foundation

enum PriceImpactPresentationStyle {
    case warning
    case danger
}

@MainActor
struct PriceImpactPresentation {
    let style: PriceImpactPresentationStyle
    let title: String
    let subtitle: String
    let description: String
    let confirmButtonTitle: String
    let backButtonTitle: String
    let didTapClose: () -> Void
    let didTapConfirm: () -> Void
    let didTapBack: () -> Void
}
