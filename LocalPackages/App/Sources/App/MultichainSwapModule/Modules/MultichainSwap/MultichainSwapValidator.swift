import BigInt
import Foundation
import KeeperCore

struct MultichainSwapValidator {
    let calculator: MultichainSwapAmountCalculator
    let swapWallet: MultichainSwapWallet

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
        let effectiveSourceAmount = MultichainSwapSourceCharge.balanceAmount(
            requested: amount,
            route: selectedRoute,
            asset: inputs.sendAsset
        )
        guard effectiveSourceAmount <= inputs.sendAsset.balance else {
            return .insufficientBalance
        }
        guard let sourceChain = inputs.sendAsset.asset.chain,
              let destinationChain = inputs.receiveAsset.asset.chain,
              swapWallet.address(for: sourceChain) != nil,
              swapWallet.address(for: destinationChain) != nil
        else {
            return .missingAddress
        }
        guard selectedRoute != nil else {
            return .routeUnavailable
        }
        return .valid
    }
}

enum MultichainSwapSourceCharge {
    /// One ulp of a Double near 10^18 is a few hundred base units. 10^-12 relative
    /// still covers that echo and stays well under a real fee or a resized quote.
    private static let roundingSlackDenominator = BigUInt(1_000_000_000_000)

    /// What a balance check should compare. A TON-native route spends its message
    /// value, gas included, so that figure wins. Otherwise `source_amount` is an
    /// echo of the request: aggregators round it through floating point, and a
    /// max quote can come back a few units above the balance that was sent.
    static func balanceAmount(
        requested: BigUInt,
        route: MultichainSwapRoute?,
        asset: MultichainAsset
    ) -> BigUInt {
        guard let route,
              let spent = route.spentSourceAmount(sourceAsset: asset)
        else {
            return requested
        }
        let echoed = route.sourceAmount.flatMap { BigUInt($0) }
        if let echoed, spent != echoed {
            return spent
        }
        return tradeAmount(requested: requested, route: route)
    }

    static func tradeAmount(
        requested: BigUInt,
        route: MultichainSwapRoute?
    ) -> BigUInt {
        guard let quoted = route?.sourceAmount.flatMap({ BigUInt($0) }) else {
            return requested
        }
        guard quoted > requested, requested > 0 else {
            return quoted
        }
        let excess = quoted - requested
        if excess * roundingSlackDenominator <= requested {
            return requested
        }
        return quoted
    }
}
