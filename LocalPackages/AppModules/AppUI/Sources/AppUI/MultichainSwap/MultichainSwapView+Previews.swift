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
#Preview("Empty") {
    MultichainSwapView(
        state: .previewEmpty(.init(mode: .hidden)),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Empty + No battery · Promo") {
    MultichainSwapView(
        state: .previewEmpty(.init(mode: .batteryPromo(TKLocales.MultichainSwap.Screen.Swap.NetworkFee.batteryPromo))),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Locked pair") {
    MultichainSwapView(
        state: .previewLoaded,
        actions: .previewLockedPair
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
        state: .previewQuoteFailed(message: TKLocales.NativeSwap.Quote.Rate.unavailable),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Pair unavailable") {
    MultichainSwapView(
        state: .previewQuoteFailed(message: TKLocales.NativeSwap.Quote.Rate.pairUnavailable),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Offline") {
    MultichainSwapView(
        state: .previewOffline,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Insufficient balance") {
    MultichainSwapView(
        state: .previewInsufficientBalance,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Below minimum") {
    MultichainSwapView(
        state: .previewBelowMinimum,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Swapping") {
    MultichainSwapView(
        state: .previewSwapping,
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Price impact 3–5%") {
    MultichainSwapView(
        state: .previewPriceImpact(.warning),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Price impact ≥5%") {
    MultichainSwapView(
        state: .previewPriceImpact(.danger),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Estimating fee") {
    MultichainSwapView(
        state: .previewFee(.previewEstimatingFee),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Fee · Token") {
    MultichainSwapView(
        state: .previewFee(.previewTokenFee),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Not enough charges") {
    MultichainSwapView(
        state: .previewFee(.previewNotEnoughCharges, continueButton: .topUpBattery),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("No funds for fee") {
    MultichainSwapView(
        state: .previewFee(.previewNoFunds),
        actions: .preview
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Send failed") {
    MultichainSwapView(
        state: .previewSendFailed,
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
                quote: .previewCharges,
                continueButton: .swap(isEnabled: true)
            )
        ),
        promoTitle: TKLocales.MysteryRaffle.swapPromo,
        focusRequestID: 1
    )

    static func previewEmpty(_ quote: Quote) -> MultichainSwapViewState {
        MultichainSwapViewState(
            content: .loaded(
                Loaded(
                    sendCard: AmountCard(
                        amount: "",
                        balanceText: "Balance: 2 345",
                        rateText: "$ 0.00",
                        maximumFractionDigits: 9,
                        token: .previewTon
                    ),
                    receiveCard: AmountCard(
                        amount: "",
                        amountState: .disabled,
                        balanceText: "Balance: 10 568",
                        rateText: "$ 0.00",
                        maximumFractionDigits: 6,
                        token: .previewTon
                    ),
                    quote: quote,
                    continueButton: .blocked(TKLocales.NativeSwap.Quote.Rate.enterAmount)
                )
            ),
            focusRequestID: 1
        )
    }

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
                quote: Quote(mode: .loading),
                continueButton: .blocked(TKLocales.WalletButtons.swap)
            )
        ),
        focusRequestID: 1
    )

    static func previewQuoteFailed(message: String) -> MultichainSwapViewState {
        MultichainSwapViewState(
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
                    quote: Quote(mode: .failed(message)),
                    continueButton: .blocked(TKLocales.WalletButtons.swap)
                )
            ),
            focusRequestID: 1
        )
    }

    static let previewOffline = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: .previewSend,
                receiveCard: .previewReceive,
                quote: .previewCharges,
                continueButton: .blocked(TKLocales.WalletButtons.swap)
            )
        ),
        focusRequestID: 1
    )

    static let previewInsufficientBalance = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: AmountCard(
                    amount: "3 000",
                    exceedsBalance: true,
                    balanceText: "Balance: 2 345",
                    rateText: "$ 6,005.10",
                    maximumFractionDigits: 9,
                    token: .previewTon
                ),
                receiveCard: AmountCard(
                    amount: "5 981",
                    amountState: .disabled,
                    balanceText: "Balance: 0",
                    rateText: "$ 5,969.04",
                    maximumFractionDigits: 6,
                    token: .previewTon
                ),
                quote: .previewCharges,
                continueButton: .blocked(TKLocales.InsufficientFunds.insufficientBalance)
            )
        ),
        focusRequestID: 1
    )

    static let previewBelowMinimum = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: AmountCard(
                    amount: "0.5",
                    balanceText: "Balance: 2 345",
                    rateText: "$ 1.00",
                    maximumFractionDigits: 9,
                    token: .previewTon
                ),
                receiveCard: AmountCard(
                    amount: "0.99",
                    amountState: .disabled,
                    balanceText: "Balance: 0",
                    rateText: "$ 0.99",
                    maximumFractionDigits: 6,
                    token: .previewTon
                ),
                quote: .previewCharges,
                continueButton: .blocked(TKLocales.MultichainSwap.Screen.Swap.minimumAmount("1 TON"))
            )
        ),
        focusRequestID: 1
    )

    static let previewSwapping = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: .previewSend,
                receiveCard: .previewReceive,
                quote: .previewCharges,
                continueButton: .swap(isEnabled: true)
            )
        ),
        focusRequestID: 1,
        isSwapping: true
    )

    static func previewPriceImpact(_ severity: PriceImpact.Severity) -> MultichainSwapViewState {
        MultichainSwapViewState(
            content: .loaded(
                Loaded(
                    sendCard: .previewSend,
                    receiveCard: AmountCard(
                        amount: severity == .danger ? "0.001602" : "0.001747",
                        amountState: .disabled,
                        balanceText: "Balance: 0",
                        rateText: severity == .danger ? "$ 176.15" : "$ 192.16",
                        priceImpact: PriceImpact(
                            severity: severity,
                            text: severity == .danger ? "(−12%)" : "(−4%)"
                        ),
                        maximumFractionDigits: 8,
                        token: .previewBitcoin
                    ),
                    quote: .previewCharges,
                    continueButton: .swap(isEnabled: true)
                )
            ),
            focusRequestID: 1
        )
    }

    static func previewFee(
        _ quote: Quote,
        continueButton: ContinueButton = .swap(isEnabled: true)
    ) -> MultichainSwapViewState {
        MultichainSwapViewState(
            content: .loaded(
                Loaded(
                    sendCard: .previewSend,
                    receiveCard: .previewReceive,
                    quote: quote,
                    continueButton: continueButton
                )
            ),
            focusRequestID: 1
        )
    }

    static let previewSendFailed = MultichainSwapViewState(
        content: .loaded(
            Loaded(
                sendCard: .previewSend,
                receiveCard: .previewReceive,
                quote: .previewCharges,
                continueButton: .swap(isEnabled: true)
            )
        ),
        focusRequestID: 1,
        sendFailure: TKLocales.MultichainSwap.Screen.Swap.sendFailed
    )
}

private extension MultichainSwapViewState.Quote {
    typealias Strings = TKLocales.MultichainSwap.Screen.Swap.NetworkFee

    static let previewEstimatingFee = Self(mode: .estimatingFee)
    static let previewCharges = Self(mode: .fee(.init(text: Strings.charges("7 charges"), icon: .battery)))
    static let previewTokenFee = Self(mode: .fee(.init(text: Strings.amount("0.3 GRAM"))))
    static let previewNotEnoughCharges = Self(mode: .fee(.init(text: Strings.notEnoughCharges, icon: .battery, isShortage: true)))
    static let previewNoFunds = Self(mode: .fee(.init(text: Strings.noFunds("BNB"), icon: .exclamationMark, isShortage: true)))
}

private extension MultichainSwapViewState.AmountCard {
    static let previewSend = MultichainSwapViewState.AmountCard(
        amount: "100",
        balanceText: "Balance: 2 345",
        rateText: "$ 200.17",
        maximumFractionDigits: 9,
        token: .previewTon
    )

    static let previewReceive = MultichainSwapViewState.AmountCard(
        amount: "183.45",
        amountState: .disabled,
        balanceText: "Balance: 234.15",
        rateText: "$ 183.45",
        maximumFractionDigits: 6,
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
        applySendPercent: { _ in },
        toggleSendAmountInputMode: {},
        requestPickSendToken: {},
        updateReceiveAmount: { _ in },
        toggleReceiveAmountInputMode: {},
        requestPickReceiveToken: {},
        swapTokens: {},
        openPriceImpactInfo: {},
        openPricingDetails: {},
        openBatteryPromo: {},
        continueSwap: {},
        topUpBattery: {}
    )

    static let previewLockedPair = MultichainSwapViewActions(
        close: {},
        retryLoading: {},
        openRaffle: {},
        updateSendAmount: { _ in },
        applySendPercent: { _ in },
        toggleSendAmountInputMode: {},
        requestPickSendToken: nil,
        updateReceiveAmount: { _ in },
        toggleReceiveAmountInputMode: {},
        requestPickReceiveToken: nil,
        swapTokens: {},
        openPriceImpactInfo: {},
        openPricingDetails: {},
        openBatteryPromo: {},
        continueSwap: {},
        topUpBattery: {}
    )
}
