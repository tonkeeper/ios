import SwiftUI
import TKLocalize
import TKUIKit

@available(iOS 17.0, *)
#Preview("Loaded") {
    MultichainSwapView(
        state: .previewLoaded,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Shimmer") {
    MultichainSwapView(
        state: .init(content: .shimmer),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Fetching quote") {
    MultichainSwapView(
        state: .previewFetchingQuote,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Quote unavailable") {
    MultichainSwapView(
        state: .previewQuoteUnavailable,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Error") {
    MultichainSwapView(
        state: .init(content: .error),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

private extension MultichainSwapViewState {
    static let previewLoaded = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: AmountCard(
                    amount: "1.25",
                    balanceText: "Balance: 4.84 ETH",
                    rateText: "$ 3,025.50",
                    maximumFractionDigits: 18,
                    token: Token(
                        avatarSource: .shimmer,
                        symbol: "ETH",
                        network: "Ethereum"
                    )
                ),
                receiveCard: AmountCard(
                    amount: "4,453.1",
                    amountState: .disabled,
                    balanceText: "Balance: 12,103 TON",
                    rateText: "$ 1,155.37",
                    maximumFractionDigits: 9,
                    token: Token(
                        avatarSource: .shimmer,
                        symbol: "TON",
                        network: "TON"
                    )
                ),
                quote: Quote(
                    mode: .ready,
                    rateText: "1 ETH ≈ 3,562.5 TON",
                    progressRestartToken: 1,
                    refreshDuration: 30
                ),
                canContinue: true
            )
        ),
        promoTitle: TKLocales.MysteryRaffle.swapPromo,
        focusRequestID: 1
    )

    static let previewFetchingQuote = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: .previewSend,
                receiveCard: AmountCard(
                    amount: "",
                    amountState: .loading,
                    showsQuoteShimmer: true,
                    balanceText: "Balance: 234.15",
                    maximumFractionDigits: 8,
                    token: .previewBitcoin
                ),
                quote: Quote(
                    mode: .loading,
                    rateText: TKLocales.NativeSwap.Quote.Rate.updating,
                    refreshDuration: 30
                ),
                canContinue: false
            )
        ),
        focusRequestID: 1
    )

    static let previewQuoteUnavailable = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: .previewSend,
                receiveCard: AmountCard(
                    amount: "",
                    amountState: .disabled,
                    quoteUnavailableText: TKLocales.NativeSwap.Quote.noQuote,
                    balanceText: "Balance: 234.15",
                    rateText: "$ 0.00",
                    maximumFractionDigits: 8,
                    token: .previewBitcoin
                ),
                quote: Quote(
                    mode: .failed,
                    rateText: TKLocales.NativeSwap.Quote.Rate.unavailable,
                    refreshDuration: 30
                ),
                canContinue: false
            )
        ),
        focusRequestID: 1
    )
}

private extension MultichainSwapViewState.AmountCard {
    static let previewSend = MultichainSwapViewState.AmountCard(
        amount: "100",
        balanceText: "Balance: 2 345",
        rateText: "$ 200.17",
        maximumFractionDigits: 9,
        token: .previewTon
    )
}

private extension MultichainSwapViewState.Token {
    static let previewTon = MultichainSwapViewState.Token(
        avatarSource: .shimmer,
        symbol: "TON",
        network: "TON"
    )

    static let previewBitcoin = MultichainSwapViewState.Token(
        avatarSource: .shimmer,
        symbol: "BTC",
        network: "Bitcoin"
    )
}

private extension MultichainSwapViewActions {
    static let preview = MultichainSwapViewActions(
        close: {},
        retryLoading: {},
        openRaffle: {},
        updateSendAmount: { _ in },
        applyMaxSend: {},
        toggleSendAmountInputMode: {},
        requestPickSendToken: {},
        toggleReceiveAmountInputMode: {},
        requestPickReceiveToken: {},
        swapTokens: {},
        toggleRateDisplayDirection: {},
        notifyQuoteRefreshCompleted: {},
        continueSwap: {}
    )
}
