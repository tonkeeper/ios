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
    /// A refresh as a screen appears, which a read made a moment ago may answer; `refresh()` after an action.
    func refreshOnAppear()
    func fundingActivity() -> PerpsFundingActivity
    func acknowledgeDepositStatuses(_ operationIds: Set<String>)

    func lifecycle(marketId: Int64) -> PerpsMarketLifecycle

    func marketExtras(marketId: Int64) -> PerpsMarketExtras?
    func loadMarketExtras(marketId: Int64)
    func releaseMarketExtras(marketId: Int64)

    func subscribePositions(cadence: PerpsPositionsCadence)
    func unsubscribePositions(cadence: PerpsPositionsCadence)

    /// The open positions the wallet had when they last loaded on this device; nil before the first load.
    var rememberedPositionsCount: Int? { get }
    func rememberPositionsCount(_ count: Int)
}

public extension PerpsAccountStoring {
    var rememberedPositionsCount: Int? {
        nil
    }

    func rememberPositionsCount(_: Int) {}

    func acknowledgeDepositStatuses(_: Set<String>) {}

    func refreshOnAppear() {
        refresh()
    }

    func subscribePositions() {
        subscribePositions(cadence: .live)
    }

    func unsubscribePositions() {
        unsubscribePositions(cadence: .live)
    }
}
