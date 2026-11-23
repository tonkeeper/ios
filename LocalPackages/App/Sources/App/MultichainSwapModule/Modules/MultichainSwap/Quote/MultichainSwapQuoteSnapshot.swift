import Foundation
import KeeperCore

struct MultichainSwapQuoteSnapshot {
    let progressStartDate: Date?
    let quoteState: MultichainSwapQuoteState
    let selectedQuote: MultichainSwapQuote?
    let selectedRoute: MultichainSwapRoute?
    /// USD prices of the most recent ready route, carried across refresh
    /// transitions (loading/failed drop the route) so fiat display does
    /// not blink out while a new quote loads. Reset with the pair (`initial`).
    let lastKnownSourceUsdPrice: Double?
    let lastKnownDestinationUsdPrice: Double?

    var sourceUsdPrice: Double? {
        selectedRoute?.sourceUsdPrice ?? lastKnownSourceUsdPrice
    }

    var destinationUsdPrice: Double? {
        selectedRoute?.destinationUsdPrice ?? lastKnownDestinationUsdPrice
    }

    /// How far the route on screen moves the price: offline the last ready route stays on screen with its
    /// amount, and its price impact with it.
    var priceImpactSeverity: MultichainSwapPriceImpactSeverity {
        switch quoteState {
        case .ready, .failed(.offline):
            MultichainSwapPriceImpactSeverity(bps: selectedRoute?.valueDifferenceBps)
        case .idle, .loading, .failed:
            .none
        }
    }

    static func initial() -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            progressStartDate: nil,
            quoteState: .idle,
            selectedQuote: nil,
            selectedRoute: nil,
            lastKnownSourceUsdPrice: nil,
            lastKnownDestinationUsdPrice: nil
        )
    }

    static func updating(previous: MultichainSwapQuoteSnapshot) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            progressStartDate: nil,
            quoteState: .loading,
            selectedQuote: nil,
            selectedRoute: nil,
            lastKnownSourceUsdPrice: previous.sourceUsdPrice,
            lastKnownDestinationUsdPrice: previous.destinationUsdPrice
        )
    }

    static func failed(
        _ failure: MultichainSwapQuoteFailure,
        previous: MultichainSwapQuoteSnapshot
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            progressStartDate: nil,
            quoteState: .failed(failure),
            selectedQuote: nil,
            selectedRoute: nil,
            lastKnownSourceUsdPrice: previous.sourceUsdPrice,
            lastKnownDestinationUsdPrice: previous.destinationUsdPrice
        )
    }

    /// A refresh found no connection: the last ready quote for the amount, if any, stays to be shown,
    /// though nothing is offered for it.
    static func offline(
        keeping lastReady: (quote: MultichainSwapQuote, route: MultichainSwapRoute)?,
        previous: MultichainSwapQuoteSnapshot
    ) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            progressStartDate: nil,
            quoteState: .failed(.offline),
            selectedQuote: lastReady?.quote,
            selectedRoute: lastReady?.route,
            lastKnownSourceUsdPrice: previous.sourceUsdPrice,
            lastKnownDestinationUsdPrice: previous.destinationUsdPrice
        )
    }

    static func ready(quote: MultichainSwapQuote, route: MultichainSwapRoute) -> MultichainSwapQuoteSnapshot {
        MultichainSwapQuoteSnapshot(
            progressStartDate: Date(),
            quoteState: .ready,
            selectedQuote: quote,
            selectedRoute: route,
            lastKnownSourceUsdPrice: route.sourceUsdPrice,
            lastKnownDestinationUsdPrice: route.destinationUsdPrice
        )
    }
}
