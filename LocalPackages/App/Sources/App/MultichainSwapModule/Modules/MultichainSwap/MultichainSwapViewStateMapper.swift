import AppUI
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

struct MultichainSwapViewStateMapper {
    private let amountFormatter: AmountFormatter
    private let quoteRefreshDuration: TimeInterval

    init(
        amountFormatter: AmountFormatter,
        quoteRefreshDuration: TimeInterval
    ) {
        self.amountFormatter = amountFormatter
        self.quoteRefreshDuration = quoteRefreshDuration
    }

    func map(
        state: MultichainSwapViewModelState,
        promoTitle: String?,
        focusRequestID: Int
    ) -> MultichainSwapViewState {
        MultichainSwapViewState(
            content: content(for: state),
            promoTitle: promoTitle,
            focusRequestID: focusRequestID
        )
    }
}

private extension MultichainSwapViewStateMapper {
    func content(
        for state: MultichainSwapViewModelState
    ) -> MultichainSwapViewState.Content {
        switch state {
        case .shimmer:
            return .shimmer
        case .error:
            return .error
        case let .loaded(loadedState):
            return .loaded(
                MultichainSwapViewState.Loaded(
                    sendCard: sendCard(for: loadedState),
                    receiveCard: receiveCard(for: loadedState),
                    quote: quote(for: loadedState.quote),
                    canContinue: canContinue(loadedState)
                )
            )
        }
    }

    func sendCard(
        for state: MultichainSwapLoadedState
    ) -> MultichainSwapViewState.AmountCard {
        MultichainSwapViewState.AmountCard(
            amount: state.sendAmount,
            amountPrefix: state.sendAmountFiatSymbol,
            insufficientBalanceText: state.validationState == .insufficientBalance
                ? TKLocales.InsufficientFunds.insufficientBalance
                : nil,
            balanceText: TKLocales.NativeSwap.balance(
                state.sendAsset.swapFormattedBalance(amountFormatter: amountFormatter)
            ),
            rateText: state.sendCardRateText,
            maximumFractionDigits: maximumFractionDigits(
                inputMode: state.sendAmountInputMode,
                asset: state.sendAsset
            ),
            decimalSeparator: decimalSeparator,
            token: token(for: state.sendAsset)
        )
    }

    func receiveCard(
        for state: MultichainSwapLoadedState
    ) -> MultichainSwapViewState.AmountCard {
        MultichainSwapViewState.AmountCard(
            amount: state.receiveAmount,
            amountPrefix: state.receiveAmountFiatSymbol,
            amountState: state.quote.quoteState == .loading ? .loading : .disabled,
            showsQuoteShimmer: state.shouldShowReceiveQuoteShimmer,
            quoteUnavailableText: state.isReceiveQuoteUnavailable
                ? TKLocales.NativeSwap.Quote.noQuote
                : nil,
            balanceText: TKLocales.NativeSwap.balance(
                state.receiveAsset.swapFormattedBalance(amountFormatter: amountFormatter)
            ),
            rateText: state.receiveCardRateText,
            maximumFractionDigits: maximumFractionDigits(
                inputMode: state.receiveAmountInputMode,
                asset: state.receiveAsset
            ),
            decimalSeparator: decimalSeparator,
            token: token(for: state.receiveAsset)
        )
    }

    var decimalSeparator: String {
        AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."
    }

    func token(
        for asset: MultichainAsset
    ) -> MultichainSwapViewState.Token {
        MultichainSwapViewState.Token(
            avatarSource: asset.swapAvatarSource,
            symbol: asset.swapDisplaySymbol,
            network: asset.swapNetworkTag
        )
    }

    func maximumFractionDigits(
        inputMode: MultichainSwapAmountInputMode,
        asset: MultichainAsset
    ) -> Int {
        switch inputMode {
        case .crypto:
            return asset.asset.decimals
        case .fiat:
            return 2
        }
    }

    func quote(
        for quote: MultichainSwapQuoteSnapshot
    ) -> MultichainSwapViewState.Quote {
        MultichainSwapViewState.Quote(
            mode: quoteMode(for: quote.quoteState),
            rateText: quote.rateText.stringValue,
            progressRestartToken: quote.progressRestartToken,
            refreshDuration: quoteRefreshDuration
        )
    }

    func quoteMode(
        for state: MultichainSwapQuoteState
    ) -> MultichainSwapViewState.Quote.Mode {
        switch state {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .ready:
            return .ready
        case .expired:
            return .expired
        case .failed:
            return .failed
        }
    }

    func canContinue(_ state: MultichainSwapLoadedState) -> Bool {
        guard state.validationState == .valid,
              state.quote.quoteState == .ready,
              let selectedRoute = state.quote.selectedRoute,
              selectedRoute.dateExpire > Date()
        else {
            return false
        }
        return true
    }
}
