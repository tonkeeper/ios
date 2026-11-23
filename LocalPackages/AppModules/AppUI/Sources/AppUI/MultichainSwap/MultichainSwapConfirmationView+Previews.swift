import SwiftUI
import TKLocalize
import TKUIKit

@available(iOS 17.0, *)
#Preview("Battery", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewReady, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Fee in token", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewTokenFee, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Temporary reserve", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewTemporaryReserve, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Calculating fee", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewCalculating, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("No fee method", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewBatteryShort, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("No funds for fee", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewInsufficientFee, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Quote failed", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewQuoteFailed, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Swap status unknown", traits: .sizeThatFitsLayout) {
    MultichainSwapConfirmationView(state: .previewStatusUnknown, actions: .preview)
        .frame(width: 390)
        .tkPreviewTheme(.deepBlue)
}

private extension MultichainSwapConfirmationViewState {
    static let previewReady = previewGramToBitcoin(networkFee: .previewCharges)

    static let previewTokenFee = previewGramToBitcoin(networkFee: .previewGram)

    static let previewTemporaryReserve = previewGramToBitcoin(
        networkFee: .previewCharges,
        temporaryReserve: TemporaryReserve(
            value: "≈ 21 charges",
            hint: TKLocales.MultichainSwap.Screen.Confirm.TemporaryReserve.chargesInfo("21 charges")
        )
    )

    static let previewCalculating = previewGramToBitcoin(
        networkFee: NetworkFee(
            title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            value: TKLocales.MultichainSwap.Screen.Confirm.Value.calculating,
            method: "",
            subtitle: TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTime(2),
            canPickMethod: false
        )
    )

    static let previewBatteryShort = previewGramToBitcoin(
        networkFee: NetworkFee(
            title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            value: "7 charges",
            method: "Battery",
            subtitle: TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnoughCharges("3"),
            isShortage: true,
            canPickMethod: true
        ),
        action: .topUpBattery
    )

    static let previewInsufficientFee = MultichainSwapConfirmationViewState(
        rateLine: "1 USD₮ ≈ 0.4986 GRAM",
        quoteProgress: .countdown(startDate: Date(), duration: 60),
        minimumReceivedLine: "≈ 49.06 GRAM",
        minimumReceivedFiatLine: "≈ $98.20",
        slippageLine: "1%",
        canSelectSlippage: true,
        networkFee: NetworkFee(
            title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            value: "≈ 0.00008",
            method: "BNB",
            subtitle: TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.notEnough("BNB"),
            isShortage: true,
            canPickMethod: true
        ),
        action: .swap(isEnabled: false, isLoading: false)
    )

    static let previewQuoteFailed = MultichainSwapConfirmationViewState(
        rateLine: "1 GRAM ≈ 0.0000182 BTC",
        quoteProgress: .none,
        minimumReceivedLine: "≈ 0.001792 BTC",
        minimumReceivedFiatLine: "≈ $197.06",
        slippageLine: "1%",
        canSelectSlippage: true,
        networkFee: NetworkFee(
            title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            value: TKLocales.MultichainSwap.Screen.Confirm.Value.calculating,
            method: "",
            subtitle: "",
            canPickMethod: false
        ),
        action: .quoteFailed(TKLocales.MultichainSwap.Screen.Confirm.Error.networkError)
    )

    static let previewStatusUnknown = MultichainSwapConfirmationViewState(
        rateLine: "1 USDT ≈ 0.9991 USD₮",
        quoteProgress: .countdown(startDate: Date(), duration: 60),
        minimumReceivedLine: "≈ 4.47 USD₮",
        minimumReceivedFiatLine: "≈ $4.47",
        slippageLine: "1%",
        canSelectSlippage: false,
        networkFee: .previewGram,
        action: .sendFailed(TKLocales.MultichainSwap.Screen.Confirm.Error.statusUnknown)
    )

    static func previewGramToBitcoin(
        networkFee: NetworkFee,
        temporaryReserve: TemporaryReserve? = nil,
        action: Action = .swap(isEnabled: true, isLoading: false)
    ) -> MultichainSwapConfirmationViewState {
        MultichainSwapConfirmationViewState(
            rateLine: "1 GRAM ≈ 0.0000182 BTC",
            quoteProgress: .countdown(startDate: Date(), duration: 60),
            minimumReceivedLine: "≈ 0.001792 BTC",
            minimumReceivedFiatLine: "≈ $197.06",
            slippageLine: "1%",
            canSelectSlippage: true,
            networkFee: networkFee,
            temporaryReserve: temporaryReserve,
            action: action
        )
    }
}

private extension MultichainSwapConfirmationViewState.NetworkFee {
    static let previewCharges = Self(
        title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
        value: "7 charges",
        method: "Battery",
        subtitle: TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTime(2),
        canPickMethod: true
    )

    static let previewGram = Self(
        title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
        value: "≈ 0.3",
        method: "GRAM",
        subtitle: TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.estimatedTime(2),
        canPickMethod: true
    )
}

private extension MultichainSwapConfirmationViewActions {
    static let preview = MultichainSwapConfirmationViewActions(
        confirm: {},
        retryQuote: {},
        selectSlippage: { _ in },
        pickFeeMethod: {},
        topUpBattery: {}
    )
}
