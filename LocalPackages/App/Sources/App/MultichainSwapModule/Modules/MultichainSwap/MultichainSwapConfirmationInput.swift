import BigInt
import Foundation
import KeeperCore

struct MultichainSwapConfirmationUserInput {
    /// What a fresh quote asks for: the amount to receive as entered, or the amount to send as the swap
    /// screen's route trades it.
    let quoteAmount: MultichainSwapQuoteAmount
    let sendAsset: MultichainAsset
    let receiveAsset: MultichainAsset
    let slippage: MultichainSwapSlippage?
    let isMax: Bool
    /// The slippage the swap screen asked its quote with: the pick from the pricing details, else the default.
    let slippageBps: Int
    let feeMethod: MultichainSwapFeeMethod?
    /// USD → display-currency rate the swap screen priced its amounts with.
    let usdFiatRate: Decimal?
}

struct MultichainSwapConfirmationQuoteState {
    let quote: MultichainSwapQuote
    let route: MultichainSwapRoute
}

struct MultichainSwapConfirmationInput {
    let userInput: MultichainSwapConfirmationUserInput
    let quoteState: MultichainSwapConfirmationQuoteState

    /// What the swap sells. For an amount to receive that is whatever the route sells for it, so a fresh
    /// route the confirmation recovers moves it too.
    var sourceAmount: BigUInt {
        switch userInput.quoteAmount {
        case let .source(amount):
            amount
        case .destination:
            quoteState.route.quotedSourceAmount ?? .zero
        }
    }

    /// The most the swap may sell, as the quote put it to the user: the amount entered, or for an
    /// amount to receive the cap the route puts on what it sells.
    var spendLimit: BigUInt {
        switch userInput.quoteAmount {
        case let .source(amount):
            amount
        case .destination:
            quoteState.route.quotedMaximumSourceAmount ?? sourceAmount
        }
    }
}
