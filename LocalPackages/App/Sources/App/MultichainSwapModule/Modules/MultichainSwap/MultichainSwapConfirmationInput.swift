import BigInt
import KeeperCore

struct MultichainSwapConfirmationUserInput {
    let sendAmount: String
    let rateText: String
    let sourceAmount: BigUInt
    let sendAsset: MultichainAsset
    let receiveAsset: MultichainAsset
    let slippage: MultichainSwapSlippage?
    let isMax: Bool
}

struct MultichainSwapConfirmationQuoteState {
    let quote: MultichainSwapQuote
    let route: MultichainSwapRoute
}

struct MultichainSwapConfirmationInput {
    let userInput: MultichainSwapConfirmationUserInput
    let quoteState: MultichainSwapConfirmationQuoteState
}
