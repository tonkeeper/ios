import AppUI
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

struct MultichainSwapViewStateMapper {
    private let amountFormatter: AmountFormatter
    private let now: () -> Date

    init(amountFormatter: AmountFormatter, now: @escaping () -> Date = Date.init) {
        self.amountFormatter = amountFormatter
        self.now = now
    }

    func map(
        state: MultichainSwapViewModelState,
        promoTitle: String?,
        focusRequestID: Int,
        isSwapping: Bool = false,
        sendFailure: MultichainSwapSendFailure? = nil
    ) -> MultichainSwapViewState {
        MultichainSwapViewState(
            content: content(for: state),
            promoTitle: promoTitle,
            focusRequestID: focusRequestID,
            focusField: focusField(for: state),
            isSwapping: isSwapping,
            sendFailure: sendFailure.map { title(for: $0) }
        )
    }
}

private extension MultichainSwapViewStateMapper {
    func focusField(for state: MultichainSwapViewModelState) -> MultichainSwapAmountField {
        guard case let .loaded(loadedState) = state,
              loadedState.enteredField == .receive,
              loadedState.isReceiveAmountEditable
        else {
            return .send
        }
        return .receive
    }

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
                    quote: MultichainSwapViewState.Quote(mode: quoteMode(for: loadedState)),
                    continueButton: continueButton(for: loadedState)
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
            amountState: amountState(in: .send, for: state),
            showsQuoteShimmer: state.showsQuoteShimmer(in: .send),
            quoteUnavailableText: state.isQuoteUnavailable(in: .send)
                ? TKLocales.NativeSwap.Quote.noQuote
                : nil,
            exceedsBalance: state.validationState == .insufficientBalance,
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
            amountState: amountState(in: .receive, for: state),
            showsQuoteShimmer: state.showsQuoteShimmer(in: .receive),
            quoteUnavailableText: state.isQuoteUnavailable(in: .receive)
                ? TKLocales.NativeSwap.Quote.noQuote
                : nil,
            balanceText: TKLocales.NativeSwap.balance(
                state.receiveAsset.swapFormattedBalance(amountFormatter: amountFormatter)
            ),
            rateText: state.receiveCardRateText,
            priceImpact: priceImpact(for: state.quote),
            maximumFractionDigits: maximumFractionDigits(
                inputMode: state.receiveAmountInputMode,
                asset: state.receiveAsset
            ),
            decimalSeparator: decimalSeparator,
            token: token(for: state.receiveAsset)
        )
    }

    func amountState(
        in field: MultichainSwapAmountField,
        for state: MultichainSwapLoadedState
    ) -> MultichainSwapAmountState {
        if field == state.quotedField, state.quote.quoteState == .loading {
            return .loading
        }
        return field == .send || state.isReceiveAmountEditable ? .editable : .disabled
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

    func priceImpact(
        for quote: MultichainSwapQuoteSnapshot
    ) -> MultichainSwapViewState.PriceImpact? {
        guard let bps = quote.selectedRoute?.valueDifferenceBps,
              let severity = quote.priceImpactSeverity.viewSeverity
        else {
            return nil
        }
        return MultichainSwapViewState.PriceImpact(
            severity: severity,
            text: "(\(amountFormatter.swapPriceImpactPercent(bps: bps)))"
        )
    }

    func quoteMode(
        for state: MultichainSwapLoadedState
    ) -> MultichainSwapViewState.Quote.Mode {
        switch state.quote.quoteState {
        case .idle:
            return state.showsBatteryPromo
                ? .batteryPromo(TKLocales.MultichainSwap.Screen.Swap.NetworkFee.batteryPromo)
                : .hidden
        case .loading:
            return .loading
        case .ready where !state.validationState.canEstimateFee:
            return .hidden
        case .ready:
            guard let summary = state.feeSummary else {
                return .estimatingFee
            }
            return fee(for: summary).map { .fee($0) } ?? .hidden
        // Offline keeps an available fee estimate; without one, the row stays hidden.
        case .failed(.offline):
            return state.feeSummary.flatMap(fee(for:)).map { .fee($0) } ?? .hidden
        case .failed(.unavailable):
            return .failed(TKLocales.NativeSwap.Quote.Rate.unavailable)
        case .failed(.pairUnavailable):
            return .failed(TKLocales.NativeSwap.Quote.Rate.pairUnavailable)
        case .failed(.walletScreened):
            return .failed(TKLocales.MultichainSwap.ProviderError.walletScreened)
        }
    }

    func fee(for summary: MultichainSwapFeeSummary) -> MultichainSwapViewState.Quote.Fee? {
        typealias Strings = TKLocales.MultichainSwap.Screen.Swap.NetworkFee
        switch summary {
        case let .charges(count):
            return .init(
                text: Strings.charges("\(count) \(TKLocales.Battery.Refill.chargesCount(count: count))"),
                icon: .battery
            )
        case let .amounts(amounts):
            return .init(text: Strings.amount(amounts.map(formatted).joined(separator: " + ")))
        case .batteryEmpty, .lowBattery:
            return .init(text: Strings.notEnoughCharges, icon: .battery, isShortage: true)
        case let .noFunds(symbol):
            return .init(text: Strings.noFunds(symbol), icon: .exclamationMark, isShortage: true)
        case .unknown:
            return nil
        }
    }

    func formatted(_ amount: MultichainSwapFeeSummary.Amount) -> String {
        amountFormatter.format(
            amount: amount.amount,
            fractionDigits: amount.asset.decimals,
            accessory: .tokenSymbol(amount.asset.symbol),
            style: .compact
        )
    }

    func continueButton(
        for state: MultichainSwapLoadedState
    ) -> MultichainSwapViewState.ContinueButton {
        let enterAmount = MultichainSwapViewState.ContinueButton.blocked(TKLocales.NativeSwap.Quote.Rate.enterAmount)
        // A swap that cannot go keeps its title; the row under the cards says why.
        let unavailableSwap = MultichainSwapViewState.ContinueButton.blocked(TKLocales.WalletButtons.swap)
        switch state.validationState {
        case .emptyAmount, .invalidAmount:
            return enterAmount
        case .insufficientBalance:
            return .blocked(TKLocales.InsufficientFunds.insufficientBalance)
        case let .belowMinimum(minimum):
            return .blocked(
                TKLocales.MultichainSwap.Screen.Swap.minimumAmount(
                    amountFormatter.format(
                        amount: minimum,
                        fractionDigits: state.sendAsset.asset.decimals,
                        accessory: .tokenSymbol(state.sendAsset.swapDisplaySymbol),
                        style: .compact
                    )
                )
            )
        case .missingAddress:
            return unavailableSwap
        case .routeUnavailable, .valid:
            break
        }
        switch state.quote.quoteState {
        case .idle:
            return enterAmount
        case .loading:
            // A refresh keeps the received amount on screen, and the button stays a primary Swap with it
            // rather than flashing every countdown.
            return state.receiveAmount.isEmpty ? unavailableSwap : .swap(isEnabled: false)
        case .ready:
            guard canContinue(state) else {
                return .swap(isEnabled: false)
            }
            switch state.feeSummary {
            case .batteryEmpty, .lowBattery:
                return .topUpBattery
            case let summary? where summary.isUnpaid:
                return .feeUnpaid
            default:
                return .swap(isEnabled: true)
            }
        case .failed:
            return unavailableSwap
        }
    }

    /// Swap waits until estimation finishes. An unknown fee opens the pricing details before the passcode.
    func canContinue(_ state: MultichainSwapLoadedState) -> Bool {
        guard state.validationState == .valid,
              state.quote.quoteState == .ready,
              state.feeSummary != nil,
              let selectedRoute = state.quote.selectedRoute,
              selectedRoute.dateExpire > now()
        else {
            return false
        }
        return true
    }

    func title(for sendFailure: MultichainSwapSendFailure) -> String {
        switch sendFailure {
        case let .retryable(reason):
            reason.isEmpty ? TKLocales.MultichainSwap.Screen.Swap.sendFailed : reason
        case .outcomeUnknown:
            TKLocales.MultichainSwap.Screen.Confirm.Error.statusUnknown
        }
    }
}

extension MultichainSwapPriceImpactSeverity {
    var viewSeverity: MultichainSwapViewState.PriceImpact.Severity? {
        switch self {
        case .none:
            nil
        case .warning:
            .warning
        case .danger:
            .danger
        }
    }
}
