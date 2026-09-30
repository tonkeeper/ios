import BigInt
import Foundation
import KeeperCore

struct MultichainSwapValidator {
    let calculator: MultichainSwapAmountCalculator
    let multichainState: MultichainWalletState

    func validate(
        _ inputs: MultichainSwapInputs,
        selectedRoute: MultichainSwapRoute?,
        usdFiatRate: Decimal?
    ) -> MultichainSwapValidationState {
        guard !inputs.sendAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .emptyAmount
        }
        guard let amount = calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: usdFiatRate
        ), amount > 0 else {
            return .invalidAmount
        }
        let effectiveSourceAmount = selectedRoute?.spentSourceAmount(sourceAsset: inputs.sendAsset) ?? amount
        guard effectiveSourceAmount <= inputs.sendAsset.balance else {
            return .insufficientBalance
        }
        guard let sourceChain = inputs.sendAsset.asset.chain,
              let destinationChain = inputs.receiveAsset.asset.chain,
              multichainState.address(for: sourceChain) != nil,
              multichainState.address(for: destinationChain) != nil
        else {
            return .missingAddress
        }
        guard selectedRoute != nil else {
            return .routeUnavailable
        }
        return .valid
    }
}
