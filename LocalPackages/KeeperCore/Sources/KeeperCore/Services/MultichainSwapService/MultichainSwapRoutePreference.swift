import Foundation

public extension MultichainSwapQuoteRequest {
    /// The backend's default aggregator set leaves SwapKit out, so a swap below swaps.xyz's minimum
    /// — or on a pair swaps.xyz does not quote — comes back with no route at all unless the client
    /// names SwapKit. `omniston` stays out of the list: including it in the whitelist makes the
    /// backend answer with an empty route list and no provider error, suppressing the other
    /// aggregators too.
    static func requestedAggregators(isSwapKitEnabled: Bool) -> [String] {
        var aggregators = [MultichainSwapAggregator.swapsXyz.rawValue]
        if isSwapKitEnabled {
            aggregators.append(MultichainSwapAggregator.swapKit.rawValue)
        }
        return aggregators
    }
}

public extension MultichainSwapQuote {
    /// swaps.xyz is the provider a swap goes through whenever it quotes one; SwapKit stands in only
    /// where swaps.xyz left no live route. The backend orders routes by neither, so the preference
    /// has to be applied here — and identically on both quote sites, or a refresh would move a
    /// confirmed swap to another provider.
    func preferredRoute(at date: Date) -> MultichainSwapRoute? {
        let liveRoutes = routes.filter { $0.dateExpire > date }
        return liveRoutes.first { $0.aggregator == MultichainSwapAggregator.swapsXyz.rawValue }
            ?? liveRoutes.first
    }
}
