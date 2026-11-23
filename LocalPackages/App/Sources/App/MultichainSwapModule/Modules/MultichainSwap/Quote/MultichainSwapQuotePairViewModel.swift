import Foundation
import KeeperCore
import TKLogging

@MainActor
final class MultichainSwapQuotePairViewModel {
    var onSnapshotChange: ((MultichainSwapQuoteSnapshot) -> Void)?
    var onProviderErrorMessage: ((String) -> Void)?
    /// A suspended quote stays ready past its route's expiry; whoever resumes it asks for a fresh one.
    var isSuspended = false

    typealias Wait = @MainActor (_ nanoseconds: UInt64) async throws -> Void

    private static let quoteDebounceNanoseconds: UInt64 = 500_000_000

    private(set) var snapshot = MultichainSwapQuoteSnapshot.initial() {
        didSet {
            onSnapshotChange?(snapshot)
        }
    }

    private let context: MultichainSwapQuotePairContext
    private let multichainSwapService: MultichainSwapService
    private let requestedAggregators: [String]
    private let debounce: Wait
    private let routeExpiryWait: Wait
    private let now: () -> Date

    private(set) var quoteTask: Task<Void, Never>?
    private var routeExpiryTask: Task<Void, Never>?
    private var amount: MultichainSwapQuoteAmount?
    private var isMax = false
    /// The last ready quote for the current amount, kept on screen when a refresh finds no connection.
    private var lastReady: (quote: MultichainSwapQuote, route: MultichainSwapRoute)?

    init(
        context: MultichainSwapQuotePairContext,
        multichainSwapService: MultichainSwapService,
        requestedAggregators: [String],
        debounce: Wait? = nil,
        routeExpiryWait: Wait? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.multichainSwapService = multichainSwapService
        self.requestedAggregators = requestedAggregators
        self.debounce = debounce ?? { try await Task.sleep(nanoseconds: $0) }
        self.routeExpiryWait = routeExpiryWait ?? { try await Task.sleep(nanoseconds: $0) }
        self.now = now
    }

    func cancel() {
        quoteTask?.cancel()
        routeExpiryTask?.cancel()
        quoteTask = nil
        routeExpiryTask = nil
    }

    func updateAmount(
        _ amount: MultichainSwapQuoteAmount?,
        isMax: Bool,
        debounce: Bool
    ) {
        quoteTask?.cancel()
        routeExpiryTask?.cancel()
        quoteTask = nil
        routeExpiryTask = nil
        if amount != self.amount || isMax != self.isMax {
            lastReady = nil
        }
        self.amount = amount
        self.isMax = isMax

        guard let amount else {
            snapshot = .initial()
            return
        }

        refreshQuote(amount: amount, debounce: debounce)
    }

    func notifyCircularProgressCompleted() {
        guard case .ready = snapshot.quoteState, let amount else {
            return
        }
        refreshQuote(amount: amount, debounce: false)
    }

    /// A quote fetched elsewhere for this pair, such as a fresh route the confirmation asked for.
    func adopt(quote: MultichainSwapQuote, route: MultichainSwapRoute) {
        guard amount != nil else {
            return
        }
        quoteTask?.cancel()
        quoteTask = nil
        lastReady = (quote, route)
        snapshot = .ready(quote: quote, route: route)
        scheduleRouteExpiry(quote: quote, route: route)
    }
}

private extension MultichainSwapQuotePairViewModel {
    func refreshQuote(
        amount: MultichainSwapQuoteAmount,
        debounce: Bool
    ) {
        quoteTask?.cancel()
        routeExpiryTask?.cancel()
        routeExpiryTask = nil
        snapshot = .updating(previous: snapshot)

        quoteTask = Task { [weak self, wait = self.debounce] in
            if debounce {
                try? await wait(Self.quoteDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self?.loadQuote(amount: amount)
        }
    }

    func loadQuote(amount: MultichainSwapQuoteAmount) async {
        Log.multichainSwap.i("[\(context)] quote request started")
        let quote: MultichainSwapQuote
        do {
            quote = try await multichainSwapService.createCrossSwapQuote(
                request: MultichainSwapQuoteRequest(
                    sourceAsset: context.source.assetId,
                    destinationAsset: context.destination.assetId,
                    amount: amount,
                    senderAddress: context.source.address,
                    recipientAddress: context.destination.address,
                    slippageBps: context.slippageBps,
                    aggregators: requestedAggregators,
                    returnDepositAddress: MultichainSwapQuoteRequest.returnDepositAddress(
                        sourceChain: context.source.chain
                    ),
                    includePayload: true,
                    isMax: isMax ? true : nil
                ),
                walletId: context.walletId,
                apiVersion: context.apiVersion
            )
        } catch {
            guard !Task.isCancelled, self.amount == amount else {
                return
            }
            if error.isPairNotAllowed {
                snapshot = .failed(.pairUnavailable, previous: snapshot)
            } else if case .transportError = error {
                snapshot = .offline(keeping: lastReady, previous: snapshot)
            } else {
                snapshot = .failed(.unavailable, previous: snapshot)
            }
            return Log.multichainSwap.w(
                "[\(context)] quote request failed",
                error: error
            )
        }
        guard !Task.isCancelled, self.amount == amount else {
            return Log.multichainSwap.i("[\(context)] quote request canceled")
        }
        let relevantRoute = quote.preferredRoute(at: now())

        guard let relevantRoute else {
            if quote.hasWalletScreenedProviderError {
                snapshot = .failed(.walletScreened, previous: snapshot)
                return Log.multichainSwap.w(
                    "[\(context)] quote request - wallet screened",
                    extraInfo: [
                        "quoteId": quote.quoteId,
                        "offeredRoutes": quote.offeredRoutesLogDescription,
                        "providerErrors": quote.providerErrorsLogDescription,
                    ]
                )
            }
            // Both missing and expired routes surface as unavailable; the provider
            // error toast carries the reason when it is available.
            if quote.routes.isEmpty {
                if quote.hasNoRouteProviderError {
                    snapshot = .failed(.pairUnavailable, previous: snapshot)
                } else {
                    snapshot = .failed(.unavailable, previous: snapshot)
                    if let message = quote.providerErrorMessage {
                        onProviderErrorMessage?(message)
                    }
                }
                return Log.multichainSwap.w(
                    "[\(context)] quote request - no routes",
                    extraInfo: [
                        "quoteId": quote.quoteId,
                        "providerErrors": quote.providerErrorsLogDescription,
                    ]
                )
            }
            snapshot = .failed(.unavailable, previous: snapshot)
            return Log.multichainSwap.w(
                "[\(context)] quote request - routes expired",
                extraInfo: [
                    "quoteId": quote.quoteId,
                    "offeredRoutes": quote.offeredRoutesLogDescription,
                ]
            )
        }

        lastReady = (quote, relevantRoute)
        snapshot = .ready(quote: quote, route: relevantRoute)
        scheduleRouteExpiry(quote: quote, route: relevantRoute)
        Log.multichainSwap.i(
            "[\(context)] quote request ready",
            extraInfo: [
                "quoteId": quote.quoteId,
                "routeId": relevantRoute.routeId,
                "aggregator": relevantRoute.aggregator,
                "protocol": relevantRoute.protocolSlug ?? "",
                "offeredRoutes": quote.offeredRoutesLogDescription,
                "providerErrors": quote.providerErrorsLogDescription,
            ]
        )
    }

    func scheduleRouteExpiry(
        quote: MultichainSwapQuote,
        route: MultichainSwapRoute
    ) {
        routeExpiryTask?.cancel()
        let timeInterval = route.dateExpire.timeIntervalSince(now())
        guard timeInterval > 0 else {
            expireRoute(quote: quote, route: route)
            return
        }

        routeExpiryTask = Task { [weak self, wait = routeExpiryWait] in
            try? await wait(UInt64(timeInterval * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            self?.expireRoute(quote: quote, route: route)
        }
    }

    func expireRoute(
        quote: MultichainSwapQuote,
        route: MultichainSwapRoute
    ) {
        guard !isSuspended,
              case .ready = snapshot.quoteState,
              snapshot.selectedQuote?.quoteId == quote.quoteId,
              snapshot.selectedRoute?.routeId == route.routeId
        else {
            return
        }
        routeExpiryTask = nil
        snapshot = .failed(.unavailable, previous: snapshot)
        Log.multichainSwap.w(
            "[\(context)] quote route expired",
            extraInfo: [
                "quoteId": quote.quoteId,
                "routeId": route.routeId,
                "aggregator": route.aggregator,
                "protocol": route.protocolSlug ?? "",
            ]
        )
    }
}
