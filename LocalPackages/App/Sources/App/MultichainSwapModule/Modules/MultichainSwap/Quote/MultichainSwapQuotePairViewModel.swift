import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKLogging

@MainActor
final class MultichainSwapQuotePairViewModel {
    var onSnapshotChange: ((MultichainSwapQuoteSnapshot) -> Void)?
    var onProviderErrorMessage: ((String) -> Void)?

    private static let quoteDebounceNanoseconds: UInt64 = 500_000_000

    @MainActor
    private(set) lazy var snapshot = snapshotMaker.initial() {
        didSet {
            switch snapshot.quoteState {
            case .ready:
                lastReadyRateText = snapshot.rateText
            case .idle, .expired, .failed:
                lastReadyRateText = nil
            case .loading:
                break
            }
            onSnapshotChange?(snapshot)
        }
    }

    private let context: MultichainSwapQuotePairContext
    private let multichainSwapService: MultichainSwapService
    private let snapshotMaker: MultichainSwapQuoteSnapshotMaker
    private let requestedAggregators: [String]

    private var quoteTask: Task<Void, Never>?
    private var routeExpiryTask: Task<Void, Never>?
    private var sourceAmount: BigUInt?
    private var isRateInverted = false
    private var lastReadyRateText: MultichainSwapQuoteText?
    init(
        context: MultichainSwapQuotePairContext,
        multichainSwapService: MultichainSwapService,
        amountFormatter: AmountFormatter,
        requestedAggregators: [String]
    ) {
        self.context = context
        self.multichainSwapService = multichainSwapService
        self.requestedAggregators = requestedAggregators
        self.snapshotMaker = MultichainSwapQuoteSnapshotMaker(
            amountFormatter: amountFormatter
        )
    }

    func cancel() {
        quoteTask?.cancel()
        routeExpiryTask?.cancel()
        quoteTask = nil
        routeExpiryTask = nil
    }

    func updateSourceAmount(
        _ sourceAmount: BigUInt?,
        debounce: Bool
    ) {
        quoteTask?.cancel()
        routeExpiryTask?.cancel()
        quoteTask = nil
        routeExpiryTask = nil
        self.sourceAmount = sourceAmount

        guard let sourceAmount, sourceAmount > 0 else {
            snapshot = snapshotMaker.initial()
            return
        }

        refreshQuote(sourceAmount: sourceAmount, debounce: debounce)
    }

    func notifyCircularProgressCompleted() {
        guard case .ready = snapshot.quoteState, let sourceAmount else {
            return
        }
        refreshQuote(sourceAmount: sourceAmount, debounce: false)
    }

    func toggleRateDisplayDirection() {
        isRateInverted.toggle()
        snapshot = snapshotMaker.inverted(snapshot)
    }
}

private extension MultichainSwapQuotePairViewModel {
    func refreshQuote(
        sourceAmount: BigUInt,
        debounce: Bool
    ) {
        quoteTask?.cancel()
        routeExpiryTask?.cancel()
        routeExpiryTask = nil
        snapshot = snapshotMaker.updating(
            lastReadyRateText: lastReadyRateText,
            previous: snapshot
        )

        quoteTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(nanoseconds: Self.quoteDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await self?.loadQuote(sourceAmount: sourceAmount)
        }
    }

    func loadQuote(sourceAmount: BigUInt) async {
        Log.multichainSwap.i("[\(context)] quote request started")
        let quote: MultichainSwapQuote
        do {
            quote = try await multichainSwapService.createCrossSwapQuote(
                request: MultichainSwapQuoteRequest(
                    sourceAsset: context.source.assetId,
                    sourceAmount: sourceAmount.description,
                    destinationAsset: context.destination.assetId,
                    senderAddress: context.source.address,
                    recipientAddress: context.destination.address,
                    slippageBps: context.slippageBps,
                    exactType: MultichainSwapQuoteRequest.exactInputType,
                    aggregators: requestedAggregators,
                    returnDepositAddress: MultichainSwapQuoteRequest.returnDepositAddress(
                        sourceChain: context.source.chain
                    ),
                    includePayload: true
                ),
                walletId: context.walletId
            )
        } catch {
            guard !Task.isCancelled, self.sourceAmount == sourceAmount else {
                return
            }
            if error.isPairNotAllowed {
                snapshot = snapshotMaker.pairUnavailable(previous: snapshot)
            } else {
                snapshot = snapshotMaker.failed(previous: snapshot)
            }
            return Log.multichainSwap.w(
                "[\(context)] quote request failed",
                error: error
            )
        }
        guard !Task.isCancelled, self.sourceAmount == sourceAmount else {
            return Log.multichainSwap.i("[\(context)] quote request canceled")
        }
        let relevantRoute = quote.preferredRoute(at: Date())

        guard let relevantRoute else {
            // Both missing and expired routes surface as unavailable; the provider
            // error toast carries the reason when it is available.
            if quote.routes.isEmpty {
                if quote.hasNoRouteProviderError {
                    snapshot = snapshotMaker.pairUnavailable(previous: snapshot)
                } else {
                    snapshot = snapshotMaker.failed(previous: snapshot)
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
            snapshot = snapshotMaker.failed(previous: snapshot)
            return Log.multichainSwap.w(
                "[\(context)] quote request - routes expired",
                extraInfo: [
                    "quoteId": quote.quoteId,
                    "offeredRoutes": quote.offeredRoutesLogDescription,
                ]
            )
        }

        snapshot = snapshotMaker.ready(
            sourceAmount: sourceAmount,
            quote: quote,
            route: relevantRoute,
            sourceSymbol: context.source.symbol,
            destinationSymbol: context.destination.symbol,
            sourceDecimals: context.source.decimals,
            destinationDecimals: context.destination.decimals,
            inverted: isRateInverted
        )
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
        let timeInterval = route.dateExpire.timeIntervalSinceNow
        guard timeInterval > 0 else {
            expireRoute(quote: quote, route: route)
            return
        }

        routeExpiryTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(timeInterval * 1_000_000_000)
            )
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
        guard case .ready = snapshot.quoteState,
              snapshot.selectedQuote?.quoteId == quote.quoteId,
              snapshot.selectedRoute?.routeId == route.routeId
        else {
            return
        }
        routeExpiryTask = nil
        snapshot = snapshotMaker.failed(previous: snapshot)
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
