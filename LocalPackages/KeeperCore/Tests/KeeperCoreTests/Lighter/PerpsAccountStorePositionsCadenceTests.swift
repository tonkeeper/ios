import Foundation
@testable import KeeperCore
import PerpsModels
import TKTestSupport
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
        XCTAssertLessThan(PerpsPositionsCadence.live.pollInterval, PerpsPositionsCadence.ambient.pollInterval)
    }

    func testOnlyAnExplicitRefreshDropsSharedReads() {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)

        store.refreshOnAppear()
        XCTAssertEqual(service.sharedReadInvalidations, 0)

        store.refresh()
        XCTAssertEqual(service.sharedReadInvalidations, 1)
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

    func testAnOpenPositionPutsTheWatchOnThePortfolio() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)

        XCTAssertEqual(store.watchFocus(), .portfolio)
    }

    func testARestingOrderAloneKeepsThePositionsWatchRunning() async {
        let service = CadenceAccountReading()
        service.openOrders = [makePortfolioOrder(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 1)

        XCTAssertEqual(store.watchFocus(), .portfolio)
    }

    func testAnOrderGoneFromThePollLeavesWithTheBalanceTheTickCarries() async {
        let service = CadenceAccountReading()
        service.openOrders = [makePortfolioOrder(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 1)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let statusReads = service.statusReads

        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(availableBalance: "90")))
        await store.flushPositionsForTesting()

        await waitForOpenOrders(on: store, count: 0)
        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.availableBalance, "90")
        XCTAssertEqual(service.statusReads, statusReads)
    }

    func testAPollThatCannotSeeOrdersKeepsTheOnesShown() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 2)]
        service.openOrders = [makePortfolioOrder(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 1)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)

        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 2, baseSize: 2)]))
        await store.flushPositionsForTesting()
        await waitForPosition(on: store, marketId: 2, baseSize: 2)

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.openOrders.map(\.marketId), [1])
    }

    func testAnOrderMovesItsMarketOnceItFillsOrLeaves() {
        let btc = makePortfolioOrder(marketId: 1)
        let eth = makePortfolioOrder(marketId: 2)
        let btcPartlyFilled = makePortfolioOrder(marketId: 1, remaining: 0.6, filled: 0.4)

        XCTAssertTrue(PerpsAccountStore.marketsWithMovedOrders(before: [btc, eth], after: [eth, btc]).isEmpty)
        XCTAssertEqual(PerpsAccountStore.marketsWithMovedOrders(before: [btc, eth], after: [btcPartlyFilled, eth]), [1])
        XCTAssertEqual(PerpsAccountStore.marketsWithMovedOrders(before: [btc, eth], after: [btc]), [2])
    }

    func testAPartialFillShowsItsProgressAndReloadsOnlyItsMarket() async {
        let service = CadenceAccountReading()
        let resting = makePortfolioOrder(marketId: 1, remaining: 0.6, filled: 0.4)
        service.positions = [makePosition(marketId: 1, baseSize: 0.4)]
        service.openOrders = [resting, makePortfolioOrder(marketId: 2)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOpenOrders(on: store, count: 2)
        store.loadMarketExtras(marketId: 1)
        store.loadMarketExtras(marketId: 2)
        await waitForSnapshotReads(on: service, count: 2)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let statusReads = service.statusReads
        let progressed = makePortfolioOrder(marketId: 1, remaining: 0.3, filled: 0.7)
        service.tradingSnapshotResult = PerpsTradingSnapshot(
            flags: nil,
            orders: PerpsActiveOrders(limitOrders: [progressed.order], triggerOrders: [])
        )

        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "80",
            positions: [makePosition(marketId: 1, baseSize: 0.7)],
            openOrders: [progressed, makePortfolioOrder(marketId: 2)]
        )))
        await store.flushPositionsForTesting()

        await waitForSnapshotReads(on: service, count: 3)
        for _ in 0 ..< 100 where store.marketExtras(marketId: 1)?.limitOrders != [progressed.order] {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.marketExtras(marketId: 1)?.limitOrders, [progressed.order])
        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.openOrders.first?.order.filledBaseAmount, 0.7)
        XCTAssertEqual(account.availableBalance, "80")
        XCTAssertEqual(Array(service.snapshotMarkets.dropFirst(2)), [1])
        XCTAssertEqual(service.statusReads, statusReads)
    }

    func testAHistoryChangeRereadsOnlyTheMarketsOnScreen() async {
        let service = CadenceAccountReading()
        var historyChanged: (() -> Void)?
        let store = PerpsAccountStore(
            service: service,
            wallet: makeWallet(),
            observeHistoryChanges: { _, onChange in historyChanged = onChange }
        )
        await resolve(store)
        store.loadMarketExtras(marketId: 1)
        store.loadMarketExtras(marketId: 2)
        await waitForSnapshotReads(on: service, count: 2)
        store.releaseMarketExtras(marketId: 2)

        historyChanged?()

        await waitForSnapshotReads(on: service, count: 3)
        XCTAssertEqual(Array(service.snapshotMarkets.dropFirst(2)), [1])
    }

    func testAPositionThatAppearsRefreshesTheWholeAccount() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        await waitForLoadedPositions(on: store)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let statusReads = service.statusReads
        service.positions = [makePosition(marketId: 1)]

        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [makePosition(marketId: 1)]
        )))
        await store.flushPositionsForTesting()

        for _ in 0 ..< 100 where service.statusReads == statusReads {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(service.statusReads, statusReads + 1)
        await waitForOnlyPosition(on: store, marketId: 1)
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
        service.positions = [makePosition(marketId: 2)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForLoadedPositions(on: store)
        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 1)
        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 99)]))
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)
        service.emitUpdate(at: 1, tick: .positions([makePosition(marketId: 2, baseSize: 2)]))
        service.emitUpdate(at: 0, tick: .positions([makePosition(marketId: 99)]))

        await store.flushPositionsForTesting()

        await waitForPosition(on: store, marketId: 2, baseSize: 2)
    }

    func testReplacingAWatchDuringItsCreationKeepsTheNewPendingTick() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 2)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForLoadedPositions(on: store)
        service.onWatchCreated = { [weak store] index in
            if index == 0 {
                store?.subscribePositions(cadence: .live)
            } else {
                service.emitUpdate(at: index, tick: .positions([self.makePosition(marketId: 2, baseSize: 2)]))
            }
        }
        defer { service.onWatchCreated = nil }

        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 2)
        await store.flushPositionsForTesting()

        XCTAssertEqual(service.intervals, [PerpsPositionsCadence.ambient.pollInterval, PerpsPositionsCadence.live.pollInterval])
        XCTAssertEqual(service.cancelCount, 1)
        await waitForPosition(on: store, marketId: 2, baseSize: 2)
    }

    func testCancellationCanReenterTheStoreWithoutDeliveringAnOldTick() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 2)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForLoadedPositions(on: store)
        store.subscribePositions(cadence: .ambient)
        await waitForIntervals(on: service, count: 1)
        service.onCancel = { [weak store] index in
            service.emitUpdate(at: index, tick: .positions([self.makePosition(marketId: 99)]))
            store?.subscribePositions(cadence: .ambient)
        }
        defer { service.onCancel = nil }

        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 2)
        service.emitUpdate(at: 1, tick: .positions([makePosition(marketId: 2, baseSize: 2)]))
        await store.flushPositionsForTesting()

        await waitForPosition(on: store, marketId: 2, baseSize: 2)
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
            reissueReadOnlyToken: {
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

    func testARefusedTradeLeavesItsMarketAndNoOtherOutcomeDoes() async {
        let service = CadenceAccountReading()
        let position = makePosition(marketId: 1)
        service.positions = [position]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)

        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        XCTAssertEqual(store.lifecycle(marketId: 1), .closing(position))
        store.tradeSettled(operationId: "another", succeeded: false)
        XCTAssertEqual(store.lifecycle(marketId: 1), .closing(position))
        store.tradeSettled(operationId: "close", succeeded: false)

        XCTAssertEqual(store.lifecycle(marketId: 1), .open(position))
    }

    func testATradeThatWentThroughStaysUntilTheAccountShowsIt() async {
        let service = CadenceAccountReading()
        let position = makePosition(marketId: 1)
        service.positions = [position]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        store.tradeBegan(operationId: "close", marketId: 1, .closing)

        store.tradeSettled(operationId: "close", succeeded: true)
        XCTAssertEqual(store.lifecycle(marketId: 1), .closing(position))
        service.positions = []
        store.refresh()

        for _ in 0 ..< 100 where store.lifecycle(marketId: 1) != .flat {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testAConfirmedCloseRefreshesTheAccountAndShowsWhatTheReadAfterItLists() async {
        let service = CadenceAccountReading()
        let position = makePosition(marketId: 1)
        service.positions = [position]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        await store.resolveTaskForTesting?.value
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        let statusReads = service.statusReads
        let invalidations = service.sharedReadInvalidations

        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        XCTAssertEqual(service.statusReads, statusReads + 1)
        XCTAssertEqual(service.sharedReadInvalidations, invalidations + 1)
        XCTAssertEqual(store.lifecycle(marketId: 1), .open(position))
    }

    func testATickRequestedBeforeAConfirmedCloseDoesNotBringThePositionBack() async {
        let service = CadenceAccountReading()
        let position = makePosition(marketId: 1)
        service.positions = [position]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let beforeClose = ProcessInfo.processInfo.systemUptime
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        service.positions = []
        await store.positionClosed(operationId: "close", marketId: 1)
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)

        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [position],
            requestedAt: beforeClose
        )))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)

        service.emitUpdate(at: 0, tick: .positions([position], requestedAt: beforeClose))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)

        let reopened = makePosition(marketId: 1, baseSize: 2)
        service.positions = [reopened]
        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [reopened],
            requestedAt: ProcessInfo.processInfo.systemUptime
        )))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()
        XCTAssertEqual(store.lifecycle(marketId: 1), .open(reopened))
    }

    func testATickRequestedBeforeAConfirmedCloseIsIgnoredAndTheReadAfterTheCloseStays() async {
        let service = CadenceAccountReading()
        let closed = makePosition(marketId: 1)
        let kept = makePosition(marketId: 2)
        service.positions = [closed, kept]
        let store = makeStore(service: service)
        await resolve(store)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let staleAt = ProcessInfo.processInfo.systemUptime
        let stale = PerpsAccountTick.portfolio(PerpsAccountSnapshot(
            availableBalance: "80",
            positions: [closed, kept],
            requestedAt: staleAt
        ))
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        service.positions = [kept]
        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        let statusReads = service.statusReads

        for _ in 0 ..< 3 {
            service.emitUpdate(at: 0, tick: stale)
            await store.flushPositionsForTesting()
            service.emitUpdate(at: 0, tick: .positions([closed], requestedAt: staleAt))
            await store.flushPositionsForTesting()
        }
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        XCTAssertEqual(service.statusReads, statusReads)
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)

        let reopened = makePosition(marketId: 1, baseSize: 2)
        service.positions = [reopened, kept]
        service.availableBalance = "90"
        store.refresh()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        service.emitUpdate(at: 0, tick: stale)
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.positions, [reopened, kept])
        XCTAssertEqual(account.availableBalance, "90")
        XCTAssertEqual(store.lifecycle(marketId: 1), .open(reopened))
    }

    func testMarksKeepRepricingTheShownPositionsAfterAConfirmedClose() async {
        let service = CadenceAccountReading()
        let closed = makePosition(marketId: 1)
        let kept = makePosition(marketId: 2)
        service.positions = [closed, kept]
        let store = makeStore(service: service)
        await resolve(store)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let staleAt = ProcessInfo.processInfo.systemUptime
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        service.positions = [kept]
        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [closed, kept],
            requestedAt: staleAt
        )))
        await store.flushPositionsForTesting()
        service.emitUpdate(at: 0, tick: .marks([1: 120, 2: 120]))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.positions, [kept.marked(at: 120)])
        XCTAssertEqual(service.cancelCount, 0)
    }

    func testAPortfolioReadRequestedBeforeAShownTickLeavesTheTickShown() async {
        let service = CadenceAccountReading()
        service.statusResult = .account(accountIndex: 42, hasTradingKey: true, hasReadOnlyToken: true)
        service.positions = [makePosition(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let held = ResolveGate()
        service.holdNextPortfolio(at: held)
        store.refresh()
        await held.waitUntilEntered()

        let newer = makePosition(marketId: 1, baseSize: 2)
        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "70",
            positions: [newer],
            requestedAt: ProcessInfo.processInfo.systemUptime
        )))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()
        await held.open()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.positions, [newer])
        XCTAssertEqual(account.availableBalance, "70")
    }

    func testAConfirmedCloseTakesThePositionOutOfTheAccountSoANewTradeThereStartsFlat() async {
        let service = CadenceAccountReading()
        let closed = makePosition(marketId: 1)
        let kept = makePosition(marketId: 2)
        service.positions = [closed, kept]
        let store = makeStore(service: service)
        await resolve(store)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)

        service.positions = [kept]
        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()
        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.positions, [kept])

        let descriptor = PerpsOpeningDescriptor(marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 5, isLimit: false)
        store.tradeBegan(operationId: "open", marketId: 1, .opening(descriptor))
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))
        store.tradeSettled(operationId: "open", succeeded: false)
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
        await store.resolveTaskForTesting?.value
    }

    func testASecondConfirmationOfTheSameCloseStartsNoSecondRefresh() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        await store.resolveTaskForTesting?.value
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        let held = ResolveGate()
        service.holdNextPortfolio(at: held)
        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()
        let invalidations = service.sharedReadInvalidations

        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()

        XCTAssertEqual(service.sharedReadInvalidations, invalidations)
        await held.open()
        await store.resolveTaskForTesting?.value
    }

    func testARepeatedConfirmationReturnsOnlyOnceTheFirstHasTakenThePositionOut() async {
        let service = CadenceAccountReading()
        let position = makePosition(marketId: 1)
        service.positions = [position]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        await store.resolveTaskForTesting?.value
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        service.positions = []
        let queueHeld = DispatchSemaphore(value: 0)
        let progress = CloseProgress()
        store.updateState({ _ in
            progress.markHeld()
            queueHeld.wait()
            return nil
        }, completion: nil)

        let confirmations = (0 ..< 2).map { _ in
            Task {
                progress.markStarted()
                await store.positionClosed(operationId: "close", marketId: 1)
                progress.record(store.lifecycle(marketId: 1))
            }
        }
        await waitUntil(progress.changes) { progress.isHeld && progress.started == 2 }
        queueHeld.signal()
        for confirmation in confirmations {
            await confirmation.value
        }

        XCTAssertEqual(progress.lifecycles, [.flat, .flat])
        await store.resolveTaskForTesting?.value
    }

    func testALateRepeatOfAnOlderCloseLeavesTheMarketsNewPositionAlone() async {
        let service = CadenceAccountReading()
        service.positions = [makePosition(marketId: 1)]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        await store.resolveTaskForTesting?.value
        service.positions = []
        await store.positionClosed(operationId: "first", marketId: 1)
        await store.resolveTaskForTesting?.value
        service.positions = [makePosition(marketId: 1, baseSize: 2)]
        store.refresh()
        await store.resolveTaskForTesting?.value
        service.positions = []
        await store.positionClosed(operationId: "second", marketId: 1)
        await store.resolveTaskForTesting?.value
        let reopened = makePosition(marketId: 1, baseSize: 3)
        service.positions = [reopened]
        store.refresh()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        let statusReads = service.statusReads

        await store.positionClosed(operationId: "first", marketId: 1)
        await store.flushStateForTesting()

        XCTAssertEqual(store.lifecycle(marketId: 1), .open(reopened))
        XCTAssertEqual(service.statusReads, statusReads)
    }

    func testAConfirmedCloseTheStoreHasNoOverlayForIsHandledTheSame() async {
        let service = CadenceAccountReading()
        let closed = makePosition(marketId: 1)
        let kept = makePosition(marketId: 2)
        service.positions = [closed, kept]
        let store = makeStore(service: service)
        await resolve(store)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let staleAt = ProcessInfo.processInfo.systemUptime
        service.positions = [kept]

        await store.positionClosed(operationId: "recovered", marketId: 1)
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [closed, kept],
            requestedAt: staleAt
        )))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()

        guard case let .active(account) = store.currentWalletState() else { return XCTFail("store left active") }
        XCTAssertEqual(account.positions, [kept])
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testAConfirmedCloseOfAPositionTheAccountDoesNotListYetStillRefreshesAndDropsOlderReads() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        store.subscribePositions(cadence: .live)
        await waitForIntervals(on: service, count: 1)
        let staleAt = ProcessInfo.processInfo.systemUptime
        let statusReads = service.statusReads

        await store.positionClosed(operationId: "close", marketId: 1)
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()
        service.emitUpdate(at: 0, tick: .portfolio(PerpsAccountSnapshot(
            availableBalance: "100",
            positions: [makePosition(marketId: 1)],
            requestedAt: staleAt
        )))
        await store.flushPositionsForTesting()
        await store.flushStateForTesting()

        XCTAssertEqual(service.statusReads, statusReads + 1)
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testAConfirmedCloseEndsItsOverlaySoAPositionReadAfterItShowsOpen() async {
        let service = CadenceAccountReading()
        let position = makePosition(marketId: 1)
        service.positions = [position]
        let store = makeStore(service: service)
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        await store.resolveTaskForTesting?.value
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: true)
        let refilled = makePosition(marketId: 1, baseSize: 2)
        service.positions = [refilled]

        await store.positionClosed(operationId: "close", marketId: 1)
        await store.flushStateForTesting()
        await store.resolveTaskForTesting?.value
        await store.flushStateForTesting()

        XCTAssertEqual(store.lifecycle(marketId: 1), .open(refilled))
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
        placeLimitOrder(descriptor, in: store)
        let settled = expectation(description: "overlay and orders updated together")
        settled.assertForOverFulfill = false
        store.addObserver(self) { _, _ in
            guard store.lifecycle(marketId: 1) == .flat else { return }
            XCTAssertEqual(store.marketExtras(marketId: 1)?.limitOrders.map(\.id), [order.id])
            settled.fulfill()
        }

        store.loadMarketExtras(marketId: 1)
        await gate.waitUntilEntered()
        XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))
        XCTAssertNil(store.marketExtras(marketId: 1))

        await gate.open()
        await fulfillment(of: [settled], timeout: 2)
    }

    func testAnOpeningSettlesOnThePrefetchedPortfolioBeforeTheStatusAnswers() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        let descriptor = PerpsOpeningDescriptor(marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 5, isLimit: false)
        store.tradeBegan(operationId: "open", marketId: 1, .opening(descriptor))
        store.tradeSettled(operationId: "open", succeeded: true)
        let gate = ResolveGate()
        service.statusGate = gate
        service.positions = [makePosition(marketId: 1)]

        store.refresh()
        await gate.waitUntilEntered()
        await waitForOnlyPosition(on: store, marketId: 1)

        let lifecycle = store.lifecycle(marketId: 1)
        await gate.open()
        guard case .open = lifecycle else {
            return XCTFail("the opening overlay waited for the status probe: \(lifecycle)")
        }
    }

    func testAPortfolioReadFromBeforeARefreshDoesNotBringBackAClosedPosition() async {
        let service = CadenceAccountReading()
        service.statusResult = .account(accountIndex: 42, hasTradingKey: true, hasReadOnlyToken: true)
        service.positions = [makePosition(marketId: 1)]
        let (appliedResolves, resolveApplies) = AsyncStream<Void>.makeStream()
        var applied = appliedResolves.makeAsyncIterator()
        let store = PerpsAccountStore(service: service, wallet: makeWallet(), ensureAccountTier: { resolveApplies.yield() })
        await resolve(store)
        await waitForOnlyPosition(on: store, marketId: 1)
        _ = await applied.next()
        let stale = ResolveGate()
        service.holdNextPortfolio(at: stale)
        store.refresh()
        await stale.waitUntilEntered()
        _ = await applied.next()

        service.positions = []
        store.refresh()
        for _ in 0 ..< 100 where store.lifecycle(marketId: 1) != .flat {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
        let reappeared = expectation(description: "the read from before the refresh shows the closed position again")
        reappeared.isInverted = true
        store.addObserver(self) { _, event in
            if case let .didUpdate(.active(account)) = event, !account.positions.isEmpty {
                reappeared.fulfill()
            }
        }

        await stale.open()

        await fulfillment(of: [reappeared], timeout: 0.2)
        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testACountThePortfolioReplacedStaysGoneOnceThePositionCloses() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        let opening = PerpsOpeningDescriptor(
            marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 5, isLimit: false, liquidationPrice: 80
        )
        store.tradeBegan(operationId: "open", marketId: 1, .opening(opening))
        store.tradeSettled(operationId: "open", succeeded: true)
        store.positionCounted(
            operationId: "open",
            PerpsCountedPosition(baseSize: 1, entryPrice: 100, leverage: 5, isolatedMarginUsd: 20)
        )
        service.positions = [makePosition(marketId: 1)]
        store.refresh()
        await waitForOnlyPosition(on: store, marketId: 1)

        service.positions = []
        store.refresh()
        for _ in 0 ..< 100 where store.lifecycle(marketId: 1) != .flat {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(store.lifecycle(marketId: 1), .flat)
    }

    func testACountedPositionKeepsThePortfolioWatchedAfterAFailedClose() async throws {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        _ = try XCTUnwrap(openCounted(in: store, marketId: 1))
        store.tradeBegan(operationId: "close", marketId: 1, .closing)
        store.tradeSettled(operationId: "close", succeeded: false)

        XCTAssertEqual(store.watchFocus(), .portfolio)
    }

    func testARefreshReloadsTheExtrasOnScreenWithoutWaitingForTheStatus() async {
        let service = CadenceAccountReading()
        let store = makeStore(service: service)
        await resolve(store)
        store.loadMarketExtras(marketId: 1)
        await waitForSnapshotReads(on: service, count: 1)
        let gate = ResolveGate()
        service.statusGate = gate

        store.refresh()
        await gate.waitUntilEntered()

        await waitForSnapshotReads(on: service, count: 2)
        await gate.open()
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
            placeLimitOrder(descriptor, in: store)
            let settled = expectation(description: "empty or failed reload releases overlay")
            settled.assertForOverFulfill = false
            store.addObserver(self) { _, _ in
                if store.lifecycle(marketId: 1) == .flat { settled.fulfill() }
            }

            store.loadMarketExtras(marketId: 1)
            await gate.waitUntilEntered()
            XCTAssertEqual(store.lifecycle(marketId: 1), .opening(descriptor))

            await gate.open()
            await fulfillment(of: [settled], timeout: 2)
        }
    }

    func testLimitOpeningClearsWhenAccountCannotReloadExtras() {
        let store = makeStore(service: CadenceAccountReading())
        placeLimitOrder(makeLimitOpening(), in: store)

        store.loadMarketExtras(marketId: 1)

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
        placeLimitOrder(descriptor, in: store)
        store.loadMarketExtras(marketId: 1)
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
        placeLimitOrder(makeLimitOpening(), in: store)
        store.loadMarketExtras(marketId: 1)
        await gate.waitUntilEntered()
        let newer = makeLimitOpening(side: .short)
        store.tradeBegan(operationId: "newer", marketId: 1, .opening(newer))
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
        placeLimitOrder(descriptor, in: store)
        store.loadMarketExtras(marketId: 1)
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
        XCTAssertEqual(store.watchFocus(), .portfolio)

        store.releaseMarketExtras(marketId: 1)

        // Nobody is watching the market any more, so it leaves the poll focus — but the rows
        // stay cached, so coming back to the screen shows them instead of an empty section.
        XCTAssertEqual(store.watchFocus(), .idle)
        XCTAssertEqual(store.marketExtras(marketId: 1)?.limitOrders.map(\.id), ["lighter:1"])

        store.loadMarketExtras(marketId: 1)
        XCTAssertEqual(store.watchFocus(), .portfolio)
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
        XCTAssertEqual(store.watchFocus(), .portfolio)

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

    func placeLimitOrder(_ descriptor: PerpsOpeningDescriptor, in store: PerpsAccountStore) {
        store.tradeBegan(operationId: "open", marketId: descriptor.marketId, .opening(descriptor))
        store.tradeSettled(operationId: "open", succeeded: true)
    }

    func openCounted(in store: PerpsAccountStore, marketId: Int64) -> PerpsPositionSummary? {
        let operationId = "open-\(marketId)"
        let opening = PerpsOpeningDescriptor(
            marketId: marketId, symbol: "BTC", side: .long, marginUsd: 20, leverage: 5, isLimit: false, liquidationPrice: 80
        )
        store.tradeBegan(operationId: operationId, marketId: marketId, .opening(opening))
        store.tradeSettled(operationId: operationId, succeeded: true)
        store.positionCounted(
            operationId: operationId,
            PerpsCountedPosition(baseSize: 1, entryPrice: 100, leverage: 5, isolatedMarginUsd: 20)
        )
        guard case let .open(counted) = store.lifecycle(marketId: marketId) else { return nil }
        return counted
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

    func waitForPosition(on store: PerpsAccountStore, marketId: Int64, baseSize: Double, line: UInt = #line) async {
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(),
               account.positions.map(\.marketId) == [marketId],
               account.positions.first?.baseSize == baseSize
            {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("expected market \(marketId) at \(baseSize)", line: line)
    }

    func waitForLoadedPositions(on store: PerpsAccountStore, line: UInt = #line) async {
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(), account.positionsLoaded { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("positions never loaded", line: line)
    }

    func waitForSnapshotReads(on service: CadenceAccountReading, count: Int, line: UInt = #line) async {
        for _ in 0 ..< 100 {
            if service.snapshotMarkets.count >= count { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("expected \(count) trading screen reads, made \(service.snapshotMarkets.count)", line: line)
    }

    func waitForOpenOrders(on store: PerpsAccountStore, count: Int, line: UInt = #line) async {
        for _ in 0 ..< 100 {
            if case let .active(account) = store.currentWalletState(), account.openOrders.count == count { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("expected \(count) open orders", line: line)
    }

    func makePortfolioOrder(marketId: Int64, remaining: Double = 1, filled: Double = 0) -> PerpsPortfolioOrder {
        PerpsPortfolioOrder(
            marketId: marketId,
            symbol: "BTC",
            order: makeLimitOrder(id: "lighter:\(marketId)", remaining: remaining, filled: filled)
        )
    }

    func makeLimitOrder(id: String, remaining: Double = 1, filled: Double = 0) -> PerpsLimitOrderSummary {
        PerpsLimitOrderSummary(
            id: id,
            orderIndex: 7,
            clientOrderIndex: 0,
            side: .long,
            limitPrice: 100,
            remainingBaseAmount: remaining,
            filledBaseAmount: filled
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

    private var invalidations = 0

    var sharedReadInvalidations: Int {
        lock.withLock { invalidations }
    }

    func invalidateSharedReads() {
        lock.withLock { invalidations += 1 }
    }

    var accountIndex: Int64 = 42
    var tradingSnapshotDelayNanoseconds: UInt64 = 0

    var statusResult: PerpsAccountStatus?
    private var statuses = 0
    private var snapshotReads = [Int64]()

    var statusReads: Int {
        lock.withLock { statuses }
    }

    var snapshotMarkets: [Int64] {
        lock.withLock { snapshotReads }
    }

    var statusGate: ResolveGate?

    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        lock.withLock { statuses += 1 }
        onStatus?()
        if let statusGate { await statusGate.enter() }
        return statusResult ?? .account(accountIndex: accountIndex)
    }

    var positions: [PerpsPositionSummary] = []
    var openOrders: [PerpsPortfolioOrder] = []
    var availableBalance = "100"
    var tradingSnapshotResult = PerpsTradingSnapshot(flags: nil, orders: nil)
    private var nextPortfolioGate: ResolveGate?

    func holdNextPortfolio(at gate: ResolveGate) {
        lock.withLock { nextPortfolioGate = gate }
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        let snapshot = PerpsAccountSnapshot(
            availableBalance: availableBalance,
            positions: positions,
            openOrders: openOrders,
            requestedAt: ProcessInfo.processInfo.systemUptime
        )
        let gate = lock.withLock {
            defer { nextPortfolioGate = nil }
            return nextPortfolioGate
        }
        await gate?.enter()
        return snapshot
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

    func tradingSnapshot(wallet _: Wallet, marketId: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        lock.withLock { snapshotReads.append(marketId) }
        if let body = lock.withLock({ tradingSnapshotOverride }) {
            return try await body()
        }
        if tradingSnapshotDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: tradingSnapshotDelayNanoseconds)
        }
        return tradingSnapshotResult
    }
}

private final class CloseProgress: @unchecked Sendable {
    let changes = TestSignal()
    private let lock = NSLock()
    private var held = false
    private var startedCount = 0
    private var recorded = [PerpsMarketLifecycle]()

    var isHeld: Bool {
        lock.withLock { held }
    }

    var started: Int {
        lock.withLock { startedCount }
    }

    var lifecycles: [PerpsMarketLifecycle] {
        lock.withLock { recorded }
    }

    func markHeld() {
        lock.withLock { held = true }
        changes.send()
    }

    func markStarted() {
        lock.withLock { startedCount += 1 }
        changes.send()
    }

    func record(_ lifecycle: PerpsMarketLifecycle) {
        lock.withLock { recorded.append(lifecycle) }
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
