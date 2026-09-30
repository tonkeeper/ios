import Foundation
import KeeperCore

struct MultichainSwapStateMaker {
    let calculator: MultichainSwapAmountCalculator
    let validator: MultichainSwapValidator

    func make(
        inputs: MultichainSwapInputs,
        quote: MultichainSwapQuoteSnapshot
    ) -> MultichainSwapLoadedState {
        let routeUsdPrice = quote.destinationUsdPrice
        let usdFiatRate = calculator.fiatRates.effectiveUsdFiatRate(inputs: inputs, quote: quote)
        return MultichainSwapLoadedState(
            sendAmount: inputs.sendAmount,
            sendAmountInputMode: inputs.sendAmountInputMode,
            receiveAmount: receiveAmountText(
                inputs: inputs,
                usdFiatRate: usdFiatRate,
                routeUsdPrice: routeUsdPrice
            ),
            receiveAmountInputMode: inputs.receiveAmountInputMode,
            sendAmountFiatSymbol: inputs.sendAmountInputMode == .fiat
                ? calculator.fiatRates.fiatInputSymbol(for: inputs.sendAsset, usdFiatRate: usdFiatRate)
                : nil,
            receiveAmountFiatSymbol: inputs.receiveAmountInputMode == .fiat
                ? calculator.fiatRates.fiatInputSymbol(
                    for: inputs.receiveAsset,
                    usdFiatRate: usdFiatRate,
                    fallbackUsdPrice: routeUsdPrice
                )
                : nil,
            sendAsset: inputs.sendAsset,
            receiveAsset: inputs.receiveAsset,
            slippage: inputs.slippage,
            sendCardRateText: calculator.sendCardRateText(
                inputs: inputs,
                usdFiatRate: usdFiatRate,
                routeUsdPrice: quote.sourceUsdPrice
            ),
            receiveCardRateText: calculator.receiveCardRateText(
                mode: inputs.receiveAmountInputMode,
                receiveAmount: inputs.receiveAmount,
                asset: inputs.receiveAsset,
                usdFiatRate: usdFiatRate,
                routeUsdPrice: routeUsdPrice
            ),
            validationState: validator.validate(
                inputs,
                selectedRoute: quote.selectedRoute,
                usdFiatRate: usdFiatRate
            ),
            quote: quote
        )
    }

    private func receiveAmountText(
        inputs: MultichainSwapInputs,
        usdFiatRate: Decimal?,
        routeUsdPrice: Double?
    ) -> String {
        switch inputs.receiveAmountInputMode {
        case .crypto:
            return inputs.receiveAmount
        case .fiat:
            return calculator.receiveFiatDisplayAmount(
                receiveAmount: inputs.receiveAmount,
                asset: inputs.receiveAsset,
                usdFiatRate: usdFiatRate,
                routeUsdPrice: routeUsdPrice
            )
        }
    }

    func resolvedReceiveAmount(
        previous: String,
        quote: MultichainSwapQuoteSnapshot,
        receiveAsset: MultichainAsset
    ) -> String {
        switch quote.quoteState {
        case .ready:
            guard let route = quote.selectedRoute else {
                return previous
            }
            return calculator.formattedAmount(route.estimatedDestinationAmount, asset: receiveAsset)
        case .loading:
            return previous
        case .idle, .expired, .failed:
            return ""
        }
    }
}
