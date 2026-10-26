import Foundation
@testable import KeeperCore
import PerpsModels
import TonSwift
import XCTest

final class PerpsAccountStorePositionsCadenceTests: XCTestCase {
    func testTheWalletHomePollsSlowerThanATradingScreen() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)

        store.subscribePositions(cadence: .ambient)

        await waitForIntervals(on: service, count: 1)
        XCTAssertEqual(service.intervals, [PerpsPositionsCadence.ambient.pollInterval])
    }

    func testATradingScreenSpeedsUpAWatchTheWalletHomeStarted() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 1)

        store.subscribePositions(cadence: .live)

        await waitForIntervals(on: service, count: 2)
        XCTAssertEqual(service.intervals.last, PerpsPositionsCadence.live.pollInterval)
        XCTAssertEqual(service.cancelCount, 1)
    }

    func testLeavingTheTradingScreenReturnsTheWatchToTheSlowCadence() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .ambient)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)

        store.unsubscribePositions(cadence: .live)

        await waitForIntervals(on: service, count: 3)
        XCTAssertEqual(service.intervals.last, PerpsPositionsCadence.ambient.pollInterval)
    }

    func testAnOrderTheVenueDidNotNameFallsBackToWatchingPositions() {
        let named = makeLimitOrder(id: "lighter:1")
        let unnamed = makeLimitOrder(id: "")

        XCTAssertEqual(PerpsAccountStore.watchFocus(restingOrders: []), .idle)
        XCTAssertEqual(PerpsAccountStore.watchFocus(restingOrders: [named]), .orders(["lighter:1"]))
        XCTAssertEqual(PerpsAccountStore.watchFocus(restingOrders: [unnamed]), .positions)
        XCTAssertEqual(PerpsAccountStore.watchFocus(restingOrders: [named, unnamed]), .positions)
    }

    func testAFillIntoAMarketAlreadyHeldCountsAsAMove() {
        let before = PerpsAccountStore.positionShapes([makePosition(marketId: 1, baseSize: 1)])
        let after = PerpsAccountStore.positionShapes([makePosition(marketId: 1, baseSize: 1.5)])

        XCTAssertEqual(
            PerpsAccountStore.marketsWithMovedPositions(before: before, after: after),
            [1]
        )
    }

    func testAPositionThatDidNotMoveAsksForNothing() {
        let shapes = PerpsAccountStore.positionShapes([
            makePosition(marketId: 1, baseSize: 1),
            makePosition(marketId: 2, baseSize: 2),
        ])

        XCTAssertTrue(
            PerpsAccountStore.marketsWithMovedPositions(before: shapes, after: shapes).isEmpty
        )
    }

    func testAMarketThatOpenedOrClosedIsAMoveToo() {
        let before = PerpsAccountStore.positionShapes([makePosition(marketId: 1, baseSize: 1)])
        let after = PerpsAccountStore.positionShapes([makePosition(marketId: 2, baseSize: 1)])

        XCTAssertEqual(
            PerpsAccountStore.marketsWithMovedPositions(before: before, after: after),
            [1, 2]
        )
    }

    func testAnAccountWithNothingOpenAsksTheVenueNothing() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)

        XCTAssertEqual(store.watchFocus(), .idle)
    }

    func testAnOpenPositionPutsTheWatchBackOnPositions() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)

        XCTAssertEqual(store.watchFocus(), .positions)
    }

    func testARestingOrderAloneKeepsThePositionsWatchRunning() async {
        let service = CadenceAccountReading()
        service.openOrders = [makePortfolioOrder(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 1)

        XCTAssertEqual(store.watchFocus(), .positions)
    }

    func testAnOrderGoneFromThePollLeavesAndTheBalanceIsReread() async {
        let service = CadenceAccountReading()
        service.openOrders = [makePortfolioOrder(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 1)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)

        service.openOrders = []
        service.availableBalance = "90"
        service.emitUpdate(at: 0, tick: .positions([], openOrders: []))
        await store.flushPositionsForTesting()

        await waitForOpenOrders(on: store, count: 0)
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(), account.availableBalance == "90" { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("the balance was not reread after the order left")
    }

    func testAPollThatCannotSeeOrdersKeepsTheOnesShown() async {
        let service = CadenceAccountReading()
        service.openOrders = [makePortfolioOrder(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 1)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)

        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 2)], openOrders: nil))
        await store.flushPositionsForTesting()
        await waitForOnlyPosition(on: store, marketId: 2)

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.openOrders.map(\.marketId), [1])
    }

    func testOrdersMatchByMarketAndIndexWhateverTheirOrder() {
        let btc = makePortfolioOrder(marketId: 1)
        let eth = makePortfolioOrder(marketId: 2)

        XCTAssertTrue(PerpsAccountStore.sameOrders([btc, eth], [eth, btc]))
        XCTAssertFalse(PerpsAccountStore.sameOrders([btc, eth], [btc]))
    }

    func testPositionsAndRestingOrdersArePolledTogether() {
        XCTAssertEqual(
            PerpsAccountStore.watchFocus(
                hasPositions: true,
                restingOrders: [makeLimitOrder(id: "lighter:1")]
            ),
            .positionsAndOrders(["lighter:1"])
        )
    }

    func testMixedPollTickDoesNotDropThePositionUpdate() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)

        let updatedPosition = makePosition(marketId: 2)
        service.emitUpdate(
            at: 0,
            tick: .positionsAndOrders(
                [updatedPosition],
                [PerpsOrderProgress(id: "lighter:1", isResting: false, filledBaseAmount: 1)]
            )
        )
        await store.flushPositionsForTesting()

        await waitForOnlyPosition(on: store, marketId: 2)
    }

    func testAnUpdateFromAReplacedWatchIsIgnored() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 1)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)

        let stalePosition = makePosition(marketId: 99)
        service.emitUpdate(at: 0, tick: .positions([stalePosition]))
        await store.flushPositionsForTesting()

        guard case let .active(account) = store.currentWalletState() else {
            return XCTFail("expected active account")
        }
        XCTAssertFalse(account.positions.contains(where: { $0.marketId == stalePosition.marketId }))
    }

    func testAReplacedWatchCannotOverwriteTheNewWatchsPendingTick() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 1)
        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 99)]))
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)
        service.emitUpdate(at: 1, tick: .positions([makePosition(marketId: 2)]))
        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 99)]))

        await store.flushPositionsForTesting()

        await waitForOnlyPosition(on: store, marketId: 2)
    }

    func testReplacingAWatchDuringItsCreationKeepsTheNewPendingTick() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        service.onWatchCreated = { [weak store] index in
            if index == 0 {
                store?.subscribePositions(cadence: .live)
            } else {
                service.emitUpdate(at: index, tick: .positions([self.makePosition(marketId: 2)]))
            }
        }
        defer { service.onWatchCreated = nil }

        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 2)
        await store.flushPositionsForTesting()

        XCTAssertEqual(service.intervals, [PerpsPositionsCadence.ambient.pollInterval, PerpsPositionsCadence.live.pollInterval])
        XCTAssertEqual(service.cancelCount, 1)
        await waitForOnlyPosition(on: store, marketId: 2)
    }

    func testCancellationCanReenterTheStoreWithoutDeliveringAnOldTick() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 1)
        service.onCancel = { [weak store] index in
            service.emitUpdate(at: index, tick: .positions([self.makePosition(marketId: 99)]))
            store?.subscribePositions(cadence: .ambient)
        }
        defer { service.onCancel = nil }

        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)
        service.emitUpdate(at: 1, tick: .positions([makePosition(marketId: 2)]))
        await store.flushPositionsForTesting()

        await waitForOnlyPosition(on: store, marketId: 2)
    }

    func testAPositionsTickKeepsAnAccountThatStillNeedsActivation() async {
        let service = CadenceAccountReading()
        service.statusResult = .account(accountIndex: 42, hasTradingKey: false)
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)

        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 2)]))
        await store.flushPositionsForTesting()

        await waitForOnlyPosition(on: store, marketId: 2)
        guard case let .active(account) = store.currentWalletState() else {
            return XCTFail("a positions tick must keep the account active")
        }
        XCTAssertTrue(account.needsActivation)
    }

    func testAnInterruptionFromAReplacedWatchDoesNotRefreshTheAccount() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.subscribePositions(cadence: .ambient)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)
        let unexpectedRefresh = expectation(description: "cancelled watch must not refresh")
        unexpectedRefresh.isInverted = true
        service.onStatus = { unexpectedRefresh.fulfill() }
        defer { service.onStatus = nil }

        service.emitInterruption(at: 0)

        await fulfillment(of: [unexpectedRefresh], timeout: 0.1)
    }

    func testAResolveSupersededWhileIssuingTheTokenCannotReviveTheWatch() async {
        let service = CadenceAccountReading()
        let gate = ResolveGate()
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            refreshOrderAccess: {
                await gate.enter()
                return false
            }
        )
        let revived = expectation(description: "a superseded resolve must not start a watch")
        revived.isInverted = true
        service.onWatchCreated = { _ in revived.fulfill() }
        defer { service.onWatchCreated = nil }
        store.subscribePositions(cadence: .live)

        store.resolveIfNeeded()
        await gate.waitUntilEntered()
        service.statusResult = .unbound
        store.refresh()
        await gate.open()

        await fulfillment(of: [revived], timeout: 0.2)
    }

    func testLimitOpeningClearsTogetherWithReloadedOrders() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        let gate = ResolveGate()
        let order = makeLimitOrder(id: "lighter:1")
        service.setTradingSnapshot {
            await gate.enter()
            return PerpsTradingSnapshot(flags: nil, orders: PerpsActiveOrders(limitOrders: [order], triggerOrders: []))
        }
        let descriptor = makeLimitOpening()
        store.beginOpening(descriptor)
        let settled = expectation(description: "overlay and orders updated together")
        settled.assertForOverFulfill = false
        store.addObserver(self) { _, _ in
            guard store.lifecycle(marketId: 1) == .flat else { return }
            XCTAssertEqual(store.marketExtras(marketId: 1)?.limitOrders.map(\.id), [order.id])
            settled.fulfill()
        }

        store.loadMarketExtras(marketId: 1, clearingPending: true)
        await gate.waitUntilEntered()
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))
        XCTAssertNil(store.marketExtras(marketId: 1))

        await gate.open()
        await fulfillment(of: [settled], timeout: 2)
    }

    func testLimitOpeningClearsAfterEmptyOrFailedReload() async {
        for fails in [false, true] {
            let service = CadenceAccountReading()
            let store = PerpsAccountStore(service: service, wallet: makeWallet(), loadHistory: { _, _ in
                throw URLError(.notConnectedToInternet)
            })
            await resolve(store)
            let gate = ResolveGate()
            service.setTradingSnapshot {
                await gate.enter()
                if fails { throw URLError(.notConnectedToInternet) }
                return PerpsTradingSnapshot(flags: nil, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
            }
            let descriptor = makeLimitOpening()
            store.beginOpening(descriptor)
            let settled = expectation(description: "empty or failed reload releases overlay")
            settled.assertForOverFulfill = false
            store.addObserver(self) { _, _ in
                if store.lifecycle(marketId: 1) == .flat { settled.fulfill() }
            }

            store.loadMarketExtras(marketId: 1, clearingPending: true)
            await gate.waitUntilEntered()
            XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))

            await gate.open()
            await fulfillment(of: [settled], timeout: 2)
        }
    }

    func testLimitOpeningClearsWhenAccountCannotReloadExtras() {
        let store = makeStore(service: CadenceAccountReading())
        store.beginOpening(makeLimitOpening())

        store.loadMarketExtras(marketId: 1, clearingPending: true)

        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testReturningToMarketKeepsOpeningUntilLatestExtrasArrive() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        let oldGate = ResolveGate()
        service.setTradingSnapshot {
            await oldGate.enter()
            return PerpsTradingSnapshot(flags: nil, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
        }
        let descriptor = makeLimitOpening()
        store.beginOpening(descriptor)
        store.loadMarketExtras(marketId: 1, clearingPending: true)
        await oldGate.waitUntilEntered()
        store.releaseMarketExtras(marketId: 1)
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))
        let latestGate = ResolveGate()
        let order = makeLimitOrder(id: "lighter:1")
        service.setTradingSnapshot {
            await latestGate.enter()
            return PerpsTradingSnapshot(flags: nil, orders: PerpsActiveOrders(limitOrders: [order], triggerOrders: []))
        }
        store.loadMarketExtras(marketId: 1)
        await latestGate.waitUntilEntered()
        let premature = expectation(description: "old response cannot clear overlay")
        premature.isInverted = true
        let loaded = expectation(description: "latest response clears overlay")
        loaded.assertForOverFulfill = false
        store.addObserver(self) { _, _ in
            guard store.lifecycle(marketId: 1) == .flat else { return }
            if store.marketExtras(marketId: 1)?.limitOrders.map(\.id) == [order.id] {
                loaded.fulfill()
            } else {
                premature.fulfill()
            }
        }

        await oldGate.open()
        await fulfillment(of: [premature], timeout: 0.1)
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))

        await latestGate.open()
        await fulfillment(of: [loaded], timeout: 2)
    }

    func testExtrasReloadDoesNotClearANewerOpening() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        let gate = ResolveGate()
        service.setTradingSnapshot {
            await gate.enter()
            return PerpsTradingSnapshot(flags: nil, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
        }
        store.beginOpening(makeLimitOpening())
        store.loadMarketExtras(marketId: 1, clearingPending: true)
        await gate.waitUntilEntered()
        let newer = makeLimitOpening(side: .short)
        store.beginOpening(newer)
        let loaded = expectation(description: "old reload completed")
        loaded.assertForOverFulfill = false
        store.addObserver(self) { _, _ in
            guard store.marketExtras(marketId: 1) != nil else { return }
            XCTAssertEqual(store.lifecycle(marketId: 1), .opening(newer))
            loaded.fulfill()
        }

        await gate.open()
        await fulfillment(of: [loaded], timeout: 2)
    }

    func testReleasingExtrasDuringClearingReloadKeepsOpeningUntilCompletion() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        let gate = ResolveGate()
        let order = makeLimitOrder(id: "lighter:1")
        service.setTradingSnapshot {
            await gate.enter()
            return PerpsTradingSnapshot(flags: nil, orders: PerpsActiveOrders(limitOrders: [order], triggerOrders: []))
        }
        let descriptor = makeLimitOpening()
        store.beginOpening(descriptor)
        store.loadMarketExtras(marketId: 1, clearingPending: true)
        await gate.waitUntilEntered()
        let loaded = expectation(description: "placement refresh completes after leaving the page")
        loaded.assertForOverFulfill = false
        store.addObserver(self) { _, _ in
            guard store.marketExtras(marketId: 1)?.limitOrders.map(\.id) == [order.id] else { return }
            XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
            loaded.fulfill()
        }

        store.releaseMarketExtras(marketId: 1)
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))
        await gate.open()
        await fulfillment(of: [loaded], timeout: 2)
    }

    func testReleasingMarketExtrasStopsPollingThemButKeepsLastKnown() async {
        let service = CadenceAccountReading()
        service.tradingSnapshotResult = PerpsTradingSnapshot(
            flags: nil,
            orders: PerpsActiveOrders(limitOrders: [makeLimitOrder(id: "lighter:1")], triggerOrders: [])
        )
        let store = makeStore(service: service)
        await resolve(store)

        store.loadMarketExtras(marketId: 1)
        for _ in 0 ..< 100 {
            if store.marketExtras(marketId: 1) != nil { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotNil(store.marketExtras(marketId: 1))
        XCTAssertEqual(store.watchFocus(), .orders(["lighter:1"]))

        store.releaseMarketExtras(marketId: 1)

        // Nobody is watching the market any more, so it leaves the poll focus — but the rows
        // stay cached, so coming back to the screen shows them instead of an empty section.
        XCTAssertEqual(store.watchFocus(), .idle)
        XCTAssertEqual(store.marketExtras(marketId: 1)?.limitOrders.map(\.id), ["lighter:1"])

        store.loadMarketExtras(marketId: 1)
        XCTAssertEqual(store.watchFocus(), .orders(["lighter:1"]))
    }

    func testExtrasFromAnOldAccountAreNotIncludedInTheWatchFocus() async {
        let service = CadenceAccountReading()
        service.tradingSnapshotResult = PerpsTradingSnapshot(
            flags: nil,
            orders: PerpsActiveOrders(limitOrders: [makeLimitOrder(id: "lighter:1")], triggerOrders: [])
        )
        let store = makeStore(service: service)
        await resolve(store)

        store.loadMarketExtras(marketId: 1)
        for _ in 0 ..< 100 {
            if store.marketExtras(marketId: 1) != nil { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.watchFocus(), .orders(["lighter:1"]))

        service.accountIndex = 43
        service.tradingSnapshotResult = PerpsTradingSnapshot(flags: nil, orders: nil)
        service.tradingSnapshotDelayNanoseconds = 100_000_000
        store.refresh()
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(), account.accountIndex == 43 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(store.watchFocus(), .idle)
    }
}

private extension PerpsAccountStorePositionsCadenceTests {
    func makeLimitOpening(side: PerpsTradeSide = .long) -> PerpsOpeningDescriptor {
        PerpsOpeningDescriptor(marketId: 1, symbol: "BTC", side: side, marginUsd: 20, leverage: 5, isLimit: true)
    }

    /// `flush()` settles the tick, but `Store` publishes through its own serial queue, so the
    /// new state is one queue hop behind the apply and cannot be read straight afterwards.
    func waitForOnlyPosition(on store: PerpsAccountStore, marketId: Int64, line: UInt = #line) async {
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(), account.positions.map(\.marketId) == [marketId] { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("expected only market \(marketId)", line: line)
    }

    func waitForOpenOrders(on store: PerpsAccountStore, count: Int, line: UInt = #line) async {
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(), account.openOrders.count == count { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("expected \(count) open orders", line: line)
    }

    func makePortfolioOrder(marketId: Int64) -> PerpsPortfolioOrder {
        PerpsPortfolioOrder(marketId: marketId, symbol: "BTC", order: makeLimitOrder(id: "lighter:\(marketId)"))
    }

    func makeLimitOrder(id: String) -> PerpsLimitOrderSummary {
        PerpsLimitOrderSummary(
            id: id,
            orderIndex: 7,
            clientOrderIndex: 0,
            side: .long,
            limitPrice: 100,
            remainingBaseAmount: 1
        )
    }

    func makePosition(marketId: Int64, baseSize: Double = 1) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:\(marketId)",
            marketId: marketId,
            symbol: "BTC",
            side: .long,
            baseSize: baseSize,
            notionalUsd: 100,
            marginUsd: 20,
            equityUsd: 20,
            leverage: 5,
            roiPercent: nil,
            entryPrice: 100,
            liquidationPrice: 80,
            unrealizedPnlUsd: 0,
            realizedPnlUsd: 0,
            fundingPaidUsd: nil,
            liquidationDistancePercent: nil
        )
    }

    func makeStore(service: CadenceAccountReading) -> PerpsAccountStore {
        PerpsAccountStore(service: service, wallet: makeWallet())
    }

    func resolve(_ store: PerpsAccountStore) async {
        store.resolveIfNeeded()
        for _ in 0 ..< 100 {
            if case .active = store.currentWalletState() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("store never resolved")
    }

    func waitForIntervals(on service: CadenceAccountReading, count: Int) async {
        for _ in 0 ..< 100 {
            if service.intervals.count >= count { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("expected \(count) watches, started \(service.intervals.count)")
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "cadence-wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 3, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Cadence", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }
}

private final class CadenceAccountReading: PerpsAccountReading, @unchecked Sendable {
    private let lock = NSLock()
    private var startedIntervals = [TimeInterval]()
    private var cancelled = 0
    private var updates = [@Sendable (PerpsAccountTick) -> Void]()
    private var interruptions = [@Sendable () -> Void]()
    private var tradingSnapshotOverride: (@Sendable () async throws -> PerpsTradingSnapshot)?
    var onWatchCreated: ((Int) -> Void)?
    var onCancel: ((Int) -> Void)?
    var onStatus: (() -> Void)?

    var intervals: [TimeInterval] {
        lock.withLock { startedIntervals }
    }

    var cancelCount: Int {
        lock.withLock { cancelled }
    }

    var accountIndex: Int64 = 42
    var tradingSnapshotDelayNanoseconds: UInt64 = 0

    var statusResult: PerpsAccountStatus?

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        onStatus?()
        return statusResult ?? .account(accountIndex: accountIndex)
    }

    var positions: [PerpsPositionSummary] = []
    var openOrders: [PerpsPortfolioOrder] = []
    var availableBalance = "100"
    var tradingSnapshotResult = PerpsTradingSnapshot(flags: nil, orders: nil)

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        PerpsAccountSnapshot(
            availableBalance: availableBalance,
            positions: positions,
            openOrders: openOrders
        )
    }

    func watchPositions(
        wallet _: Wallet,
        pollInterval: TimeInterval,
        focus _: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        let index = lock.withLock { () -> Int in
            startedIntervals.append(pollInterval)
            updates.append(onUpdate)
            interruptions.append(onInterrupted)
            return updates.count - 1
        }
        onWatchCreated?(index)
        return PerpsPositionsWatch { [weak self] in
            guard let self else { return }
            self.lock.withLock { self.cancelled += 1 }
            self.onCancel?(index)
        }
    }

    /// An in-flight callback can outlive cancellation; the store must reject it.
    func emitUpdate(at index: Int, tick: PerpsAccountTick) {
        let update = lock.withLock { updates[index] }
        update(tick)
    }

    func emitInterruption(at index: Int) {
        let interrupt = lock.withLock { interruptions[index] }
        interrupt()
    }

    func setTradingSnapshot(_ body: @escaping @Sendable () async throws -> PerpsTradingSnapshot) {
        lock.withLock { tradingSnapshotOverride = body }
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        if let body = lock.withLock({ tradingSnapshotOverride }) {
            return try await body()
        }
        if tradingSnapshotDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: tradingSnapshotDelayNanoseconds)
        }
        return tradingSnapshotResult
    }
}

private actor ResolveGate {
    private var isOpen = false
    private var hasEntered = false
    private var blocked = [CheckedContinuation<Void, Never>]()
    private var awaitingEntry = [CheckedContinuation<Void, Never>]()

    func enter() async {
        hasEntered = true
        resume(&awaitingEntry)
        guard !isOpen else { return }
        await withCheckedContinuation { blocked.append($0) }
    }

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { awaitingEntry.append($0) }
    }

    func open() {
        isOpen = true
        resume(&blocked)
    }

    private func resume(_ continuations: inout [CheckedContinuation<Void, Never>]) {
        let waiting = continuations
        continuations = []
        for continuation in waiting {
            continuation.resume()
        }
    }
}
