import Foundation
import TKLocalize

enum PriceImpactPresentationStyle {
    case warning
    case danger
}

@MainActor
struct PriceImpactPresentation {
    let style: PriceImpactPresentationStyle
    let title: String
    let message: String
    let confirmButtonTitle: String
    let backButtonTitle: String
    let didTapClose: () -> Void
    let didTapConfirm: () -> Void
    let didTapBack: () -> Void
}

extension PriceImpactPresentation {
    /// The warning's two sentences as the one paragraph it shows, and the price impact info with it.
    static var message: String {
        [
            TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.subtitle,
            TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.description,
        ].joined(separator: " ")
    }
}
