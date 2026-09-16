import Foundation
@testable import KeeperCore
import XCTest

final class MultichainSwapRoutePreferenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func test_requestedAggregators_doesNotNameSwapKitByDefault() {
        XCTAssertEqual(
            MultichainSwapQuoteRequest.requestedAggregators(isSwapKitEnabled: false),
            ["swapsxyz"]
        )
    }

    func test_requestedAggregators_namesSwapKitWhenEnabled() {
        XCTAssertEqual(
            MultichainSwapQuoteRequest.requestedAggregators(isSwapKitEnabled: true),
            ["swapsxyz", "swapkit"]
        )
    }

    /// Including `omniston` makes the backend answer with no routes at all, so the whitelist must
    /// never grow to the full aggregator list.
    func test_requestedAggregators_leavesOmnistonOut() {
        XCTAssertFalse(
            MultichainSwapQuoteRequest.requestedAggregators(isSwapKitEnabled: true)
                .contains(MultichainSwapAggregator.omniston.rawValue)
        )
    }

    func test_preferredRoute_picksSwapsXyzOverABetterRankedSwapKitRoute() {
        let quote = makeQuote([
            makeRoute(routeId: "swapkit-route", aggregator: .swapKit),
            makeRoute(routeId: "swapsxyz-route", aggregator: .swapsXyz),
        ])

        XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, "swapsxyz-route")
    }

    func test_preferredRoute_fallsBackToSwapKitWhenSwapsXyzHasNoRoute() {
        let quote = makeQuote([
            makeRoute(routeId: "swapkit-route", aggregator: .swapKit),
        ])

        XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, "swapkit-route")
    }

    func test_preferredRoute_fallsBackToSwapKitWhenTheSwapsXyzRouteExpired() {
        let quote = makeQuote([
            makeRoute(routeId: "swapsxyz-route", aggregator: .swapsXyz, expiresIn: -1),
            makeRoute(routeId: "swapkit-route", aggregator: .swapKit),
        ])

        XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, "swapkit-route")
    }

    func test_preferredRoute_keepsTheBackendRankingAmongFallbackRoutes() {
        let quote = makeQuote([
            makeRoute(routeId: "omniston-route", aggregator: .omniston),
            makeRoute(routeId: "swapkit-route", aggregator: .swapKit),
        ])

        XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, "omniston-route")
    }

    func test_preferredRoute_isNilWhenEveryRouteExpired() {
        let quote = makeQuote([
            makeRoute(routeId: "swapsxyz-route", aggregator: .swapsXyz, expiresIn: -1),
            makeRoute(routeId: "swapkit-route", aggregator: .swapKit, expiresIn: -1),
        ])

        XCTAssertNil(quote.preferredRoute(at: now))
    }

    func test_preferredRoute_isNilWithoutRoutes() {
        XCTAssertNil(makeQuote([]).preferredRoute(at: now))
    }
}

private extension MultichainSwapRoutePreferenceTests {
    func makeQuote(_ routes: [MultichainSwapRoute]) -> MultichainSwapQuote {
        MultichainSwapQuote(quoteId: "quote", routes: routes)
    }

    func makeRoute(
        routeId: String,
        aggregator: MultichainSwapAggregator,
        expiresIn: TimeInterval = 60
    ) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: routeId,
            aggregator: aggregator.rawValue,
            routeType: "cross_chain_swap",
            estimatedDestinationAmount: "1",
            minimumDestinationAmount: "1",
            legs: [],
            dateExpire: now.addingTimeInterval(expiresIn),
            riskLevel: "low"
        )
    }
}
