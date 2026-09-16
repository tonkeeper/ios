import SwiftUI
import TKLocalize
import TKUIKit

enum PaymentMethodPlaceholderOverlayKind: Equatable {
    case empty
    case emptyNoCashForCurrency
    case loadError
}

struct PaymentMethodPlaceholderOverlayRootView: View {
    let kind: PaymentMethodPlaceholderOverlayKind
    var didTapRetry: (() -> Void)?

    var body: some View {
        switch kind {
        case .empty:
            PlaceholderView(config: PlaceholderView.Config(
                lottieResource: .magnifyingGlass,
                title: TKLocales.Ramp.Picker.Search.zeroTitle
            ))
        case .emptyNoCashForCurrency:
            PlaceholderView(config: PlaceholderView.Config(
                lottieResource: .creditCard,
                title: TKLocales.Ramp.PaymentMethod.noCashMethodsTitle,
                subtitle: TKLocales.Ramp.PaymentMethod.noCashMethodsSubtitle
            ))
        case .loadError:
            PlaceholderView(config: PlaceholderView.Config(
                lottieResource: .exclamationmarkCircle,
                title: TKLocales.Trade.Placeholder.errorTitle,
                subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.Actions.retry,
                    icon: .TKUIKit.Icons.Size16.refresh,
                    action: {
                        didTapRetry?()
                    }
                )
            ))
        }
    }
}
