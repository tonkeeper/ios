import SwiftUI
import TKLocalize
import TKUIKit

@available(iOS 17.0, *)
#Preview("Quote failure", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        MultichainSwapConfirmationQuoteFailureView(
            message: TKLocales.MultichainSwap.Screen.Confirm.Error.networkError,
            onRetry: {}
        )
        .frame(width: 343, height: 88)
        MultichainSwapConfirmationQuoteFailureView(
            message: TKLocales.MultichainSwap.ProviderError.minAmountNotMet,
            onRetry: {}
        )
        .frame(width: 343, height: 88)
        MultichainSwapConfirmationQuoteFailureView(
            message: TKLocales.MultichainSwap.Screen.Confirm.Error.networkError,
            showsRetry: true,
            onRetry: {}
        )
        .frame(width: 343, height: 88)
    }
    .padding()
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
