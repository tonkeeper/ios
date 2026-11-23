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
        guard !inputs.enteredAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .emptyAmount
        }
        guard let enteredAmount = calculator.enteredAmount(inputs: inputs, usdFiatRate: usdFiatRate) else {
            return .invalidAmount
        }
        let sourceAmount: BigUInt?
        switch enteredAmount {
        case let .source(amount):
            sourceAmount = amount
        case .destination:
            if let selectedRoute {
                sourceAmount = selectedRoute.quotedSourceAmount.flatMap { $0 > 0 ? $0 : nil }
            } else {
                // While a quote loads, the amount the send card still shows stands in for its route's,
                // so the balance checks hold through a refresh.
                sourceAmount = calculator.sourceAmount(inputs: inputs, usdFiatRate: usdFiatRate).flatMap { $0 > 0 ? $0 : nil }
            }
        }
        if let sourceAmount {
            let effectiveSourceAmount = MultichainSwapSourceCharge.balanceAmount(
                requested: sourceAmount,
                route: selectedRoute,
                asset: inputs.sendAsset
            )
            guard effectiveSourceAmount <= inputs.sendAsset.balance else {
                return .insufficientBalance
            }
            if let minimum = MultichainSwapMinimumAmount.minimumSwapInputAmount(for: inputs.sendAsset),
               sourceAmount < minimum
            {
                return .belowMinimum(minimum)
            }
        }
        guard let sourceChain = inputs.sendAsset.asset.chain,
              let destinationChain = inputs.receiveAsset.asset.chain,
              swapWallet.address(for: sourceChain) != nil,
              swapWallet.address(for: destinationChain) != nil
        else {
            return .missingAddress
        }
        guard selectedRoute != nil, sourceAmount != nil else {
            return .routeUnavailable
        }
        return .valid
    }
}

enum MultichainSwapMinimumAmount {
    /// GRAM is the one asset whose minimum is known before quoting: the same 1 GRAM the Max preset
    /// keeps back for fees. Other assets learn theirs from the provider, as `min_amount_not_met`.
    static func minimumSwapInputAmount(for asset: MultichainAsset) -> BigUInt? {
        guard asset.asset.isNative, asset.asset.chain == .ton else {
            return nil
        }
        return NativeSwapConstants.tonFeeReserve
    }
}

enum MultichainSwapSourceCharge {
    /// One ulp of a Double near 10^18 is a few hundred base units. 10^-12 relative
    /// still covers that echo and stays well under a real fee or a resized quote.
    private static let roundingSlackDenominator = BigUInt(1_000_000_000_000)

    /// What a balance check should compare. A TON-native route spends its message
    /// value, gas included, so that figure wins. Otherwise `source_amount` is an
    /// echo of the request: aggregators round it through floating point, and a
    /// max quote can come back a few units above the balance that was sent. An
    /// exact-output route is quoted again when the swap is prepared and may then
    /// sell up to its cap, so the balance has to cover the cap and whatever the
    /// route sends on top of the amount sold, such as a TON route's gas.
    static func balanceAmount(
        requested: BigUInt,
        route: MultichainSwapRoute?,
        asset: MultichainAsset
    ) -> BigUInt {
        guard let route else {
            return requested
        }
        let charged = chargedAmount(requested: requested, route: route, asset: asset)
        guard let cap = route.quotedMaximumSourceAmount,
              let quoted = route.quotedSourceAmount
        else {
            return charged
        }
        let overhead = charged > quoted ? charged - quoted : 0
        return max(charged, cap + overhead)
    }

    private static func chargedAmount(
        requested: BigUInt,
        route: MultichainSwapRoute,
        asset: MultichainAsset
    ) -> BigUInt {
        guard let spent = route.spentSourceAmount(sourceAsset: asset) else {
            return requested
        }
        let echoed = route.quotedSourceAmount
        if let echoed, spent != echoed {
            return spent
        }
        return tradeAmount(requested: requested, route: route)
    }

    static func tradeAmount(
        requested: BigUInt,
        route: MultichainSwapRoute?
    ) -> BigUInt {
        guard let quoted = route?.quotedSourceAmount else {
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
