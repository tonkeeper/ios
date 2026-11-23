import BigInt
import Foundation
import KeeperCore

struct MultichainSwapStateMaker {
    let calculator: MultichainSwapAmountCalculator
    let validator: MultichainSwapValidator
    let exactOutputSupport: MultichainSwapExactOutputSupport

    func make(
        inputs: MultichainSwapInputs,
        quote: MultichainSwapQuoteSnapshot,
        feePlan: MultichainSwapFeePlan = .preparing,
        showsBatteryPromo: Bool = false
    ) -> MultichainSwapLoadedState {
        let routeUsdPrice = quote.destinationUsdPrice
        let usdFiatRate = calculator.fiatRates.effectiveUsdFiatRate(inputs: inputs, quote: quote)
        let validationState = validator.validate(inputs, selectedRoute: quote.selectedRoute, usdFiatRate: usdFiatRate)
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
            validationState: validationState,
            quote: quote,
            feeSummary: MultichainSwapFeeSummary(
                plan: feePlan,
                picked: inputs.feeMethod,
                amountBlockedAssetId: validationState.isBelowMinimum ? inputs.sendAsset.asset.assetId : nil
            ),
            enteredField: inputs.enteredField,
            isReceiveAmountEditable: acceptsReceiveAmount(inputs),
            showsBatteryPromo: showsBatteryPromo
        )
    }

    /// Only a pair quoted by the amount to receive takes it typed, and only as crypto: fiat mode just
    /// renders it.
    func acceptsReceiveAmount(_ inputs: MultichainSwapInputs) -> Bool {
        inputs.receiveAmountInputMode == .crypto
            && exactOutputSupport.supports(sendAsset: inputs.sendAsset, receiveAsset: inputs.receiveAsset)
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

    func resolvedQuotedAmount(
        inputs: MultichainSwapInputs,
        quote: MultichainSwapQuoteSnapshot
    ) -> String {
        let previous = inputs.quotedAmountText
        switch quote.quoteState {
        // Offline the last quote for the amount stays on screen, with no swap offered for it.
        case .ready, .failed(.offline):
            guard let route = quote.selectedRoute else {
                return quote.quoteState == .ready ? previous : ""
            }
            // A zero is left empty: the editable card would complete "0" to "0." and take it as typed.
            switch inputs.enteredField {
            case .send:
                guard let amount = BigUInt(route.estimatedDestinationAmount), amount > 0 else {
                    return ""
                }
                return calculator.formattedAmount(route.estimatedDestinationAmount, asset: inputs.receiveAsset)
            case .receive:
                guard let sourceAmount = route.quotedSourceAmount else {
                    return previous
                }
                guard sourceAmount > 0 else {
                    return ""
                }
                return calculator.inputAmountString(
                    sourceAmount: sourceAmount,
                    mode: inputs.sendAmountInputMode,
                    asset: inputs.sendAsset,
                    usdFiatRate: calculator.fiatRates.effectiveUsdFiatRate(inputs: inputs, quote: quote)
                )
            }
        case .loading:
            return previous
        case .idle, .failed:
            return ""
        }
    }
}
