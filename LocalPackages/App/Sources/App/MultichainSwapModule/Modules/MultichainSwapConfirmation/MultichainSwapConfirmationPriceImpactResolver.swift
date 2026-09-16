import KeeperCore

struct MultichainSwapConfirmationPriceImpactResolver {
    func priceImpactBps(input: MultichainSwapConfirmationInput) -> Int? {
        input.quoteState.route.valueDifferenceBps
    }

    func severity(input: MultichainSwapConfirmationInput) -> MultichainSwapPriceImpactSeverity {
        MultichainSwapPriceImpactSeverity(bps: priceImpactBps(input: input))
    }
}
