import Foundation

/// How often the positions stream is polled. The perps screens act on these numbers,
/// the wallet home only displays them.
public enum PerpsPositionsCadence: Sendable, Hashable, CaseIterable {
    /// Trading screens, where a number the user is about to act on must be current.
    case live
    /// The wallet home, where the section is one row among many.
    case ambient
}

/// Every perps screen observes its stores the same way: something changed, re-read the
/// state. None of them inspect the event payload, so the ports carry no event type.
public protocol PerpsStoreObserving: AnyObject {
    func addChangeObserver<T: AnyObject>(_ observer: T, onChange: @escaping (T) -> Void)
}

public protocol PerpsPriceInteresting: AnyObject {
    func set(marketIds: Set<Int64>)
    func clear()
}

public protocol PerpsMarketsStoring: PerpsStoreObserving, Sendable {
    func getState() -> PerpsMarketsState
    func subscribe()
    func unsubscribe()
    func setSort(_ sort: PerpsMarketsSort)
    func loadNextPage()
    func makePriceInterest() -> any PerpsPriceInteresting
    func price(marketId: Int64) async -> Double?
    func snapshot(marketId: Int64) async -> PerpsAssetMarketSnapshot?
}

public protocol PerpsMarketDetailsStoring: PerpsStoreObserving {
    func getState() -> PerpsMarketDetailsState
    func load(marketId: Int64)
}

public protocol PerpsAccountStoring: PerpsStoreObserving {
    func currentWalletState() -> PerpsWalletAccountState
    func resolveIfNeeded()
    func refresh()
    func fundingActivity() -> PerpsFundingActivity

    func lifecycle(marketId: Int64) -> PerpsMarketLifecycle
    func matchingPosition(marketId: Int64) -> PerpsPositionSummary?

    func beginOpening(_ descriptor: PerpsOpeningDescriptor)
    func beginClosing(marketId: Int64)
    func beginAdjusting(marketId: Int64, direction: PerpsSizeChangeDirection, baseSizeBefore: Double)
    func beginAdjustingMargin(
        marketId: Int64,
        direction: PerpsMarginChangeDirection,
        allocatedMarginBefore: Double,
        amountUsd: Double
    )
    func clearPending(marketId: Int64)

    func marketExtras(marketId: Int64) -> PerpsMarketExtras?
    func loadMarketExtras(marketId: Int64, clearingPending: Bool)
    func releaseMarketExtras(marketId: Int64)

    func subscribePositions(cadence: PerpsPositionsCadence)
    func unsubscribePositions(cadence: PerpsPositionsCadence)
}

public extension PerpsAccountStoring {
    func loadMarketExtras(marketId: Int64) {
        loadMarketExtras(marketId: marketId, clearingPending: false)
    }

    func subscribePositions() {
        subscribePositions(cadence: .live)
    }

    func unsubscribePositions() {
        unsubscribePositions(cadence: .live)
    }
}
