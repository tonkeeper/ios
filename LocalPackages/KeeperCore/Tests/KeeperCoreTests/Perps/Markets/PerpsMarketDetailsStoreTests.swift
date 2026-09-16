import Foundation
@testable import KeeperCore
import XCTest

final class PerpsMarketDetailsStoreTests: XCTestCase {
    func testLoad_dropsStaleCompletionAfterMarketChange() async {
        let spy = GatedMarketDetailsLoadingSpy()
        let store = PerpsMarketDetailsStore(service: spy)

        store.load(marketId: 1)
        await spy.waitForRequestCount(1)
        store.load(marketId: 2)
        await spy.waitForRequestCount(2)
        let recorder = DetailsStateRecorder(store)

        spy.complete(index: 0, with: .success(makeSnapshot(marketId: 1, symbol: "BTC")))
        spy.complete(index: 1, with: .success(makeSnapshot(marketId: 2, symbol: "ETH")))
        await waitUntilStore(store) {
            if case let .loaded(snapshot) = $0 { return snapshot.marketId == 2 }
            return false
        }

        XCTAssertFalse(recorder.states.contains { if case let .loaded(snapshot) = $0 { return snapshot.marketId == 1 } else { return false } })
        guard case let .loaded(snapshot) = store.getState() else {
            return XCTFail("expected loaded ETH")
        }
        XCTAssertEqual(snapshot.symbol, "ETH")
    }

    func testLoad_switchesToLoadingWhenMarketIdentityChanges() async {
        let spy = GatedMarketDetailsLoadingSpy()
        let store = PerpsMarketDetailsStore(service: spy)

        store.load(marketId: 1)
        await spy.waitForRequestCount(1)
        spy.complete(index: 0, with: .success(makeSnapshot(marketId: 1, symbol: "BTC")))
        await waitUntilStore(store) {
            if case .loaded = $0 { return true }
            return false
        }

        store.load(marketId: 2)
        await spy.waitForRequestCount(2)
        await waitUntilStore(store) {
            if case .loading = $0 { return true }
            return false
        }
        spy.complete(index: 1, with: .success(makeSnapshot(marketId: 2, symbol: "ETH")))
        await waitUntilStore(store) {
            if case let .loaded(snapshot) = $0 { return snapshot.symbol == "ETH" }
            return false
        }
    }

    func testLoad_keepsLoadedMarketWhileTheSameMarketRefreshes() async {
        let spy = GatedMarketDetailsLoadingSpy()
        let store = PerpsMarketDetailsStore(service: spy)

        store.load(marketId: 1)
        await spy.waitForRequestCount(1)
        spy.complete(index: 0, with: .success(makeSnapshot(marketId: 1, symbol: "BTC")))
        await waitUntilStore(store) {
            if case .loaded = $0 { return true }
            return false
        }

        store.load(marketId: 1)
        await spy.waitForRequestCount(2)
        guard case let .loaded(snapshot) = store.getState() else {
            return XCTFail("a same-market refresh must keep the loaded market visible")
        }
        XCTAssertEqual(snapshot.symbol, "BTC")
        let recorder = DetailsStateRecorder(store)
        spy.complete(index: 1, with: .failure(URLError(.badServerResponse)))
        store.load(marketId: 1)
        await spy.waitForRequestCount(3)
        spy.complete(index: 2, with: .success(makeSnapshot(marketId: 1, symbol: "BTC2")))
        await waitUntilStore(store) {
            if case let .loaded(snapshot) = $0 { return snapshot.symbol == "BTC2" }
            return false
        }
        XCTAssertFalse(recorder.states.contains(.failed), "a failed refresh must not replace the loaded market")
    }

    func testLoad_mapsNotFoundWithoutRetryableFailedState() async {
        let spy = GatedMarketDetailsLoadingSpy()
        let store = PerpsMarketDetailsStore(service: spy)

        store.load(marketId: 9)
        await spy.waitForRequestCount(1)
        spy.complete(index: 0, with: .failure(PerpsMarketDetailsLoadError.notFound))
        await waitUntilStore(store) { $0 == .notFound }
    }
}

private extension PerpsMarketDetailsStoreTests {
    func waitUntilStore(
        _ store: PerpsMarketDetailsStore,
        timeout: TimeInterval = 5,
        _ condition: @escaping (PerpsMarketDetailsStore.State) -> Bool
    ) async {
        let fulfilled = XCTestExpectation(description: "market details store condition")
        fulfilled.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            if case let .didUpdate(state) = event, condition(state) {
                fulfilled.fulfill()
            }
        } onRegistered: {
            if condition(store.getState()) {
                fulfilled.fulfill()
            }
        }
        await fulfillment(of: [fulfilled], timeout: timeout)
    }
}

private final class DetailsStateRecorder {
    private let lock = NSLock()
    private var _states: [PerpsMarketDetailsStore.State] = []

    init(_ store: PerpsMarketDetailsStore) {
        store.addObserver(self) { recorder, event in
            if case let .didUpdate(state) = event {
                recorder.lock.withLock { recorder._states.append(state) }
            }
        }
    }

    var states: [PerpsMarketDetailsStore.State] {
        lock.withLock { _states }
    }
}

private func makeSnapshot(marketId: Int64, symbol: String) -> PerpsAssetMarketSnapshot {
    PerpsAssetMarketSnapshot(
        marketId: marketId,
        symbol: symbol,
        displayName: symbol,
        status: "active",
        maxLeverage: 20,
        priceDecimals: 2,
        sizeDecimals: 4,
        price: 100,
        priceChangePercent: 0,
        priceChangeAmount: 0,
        volume24h: 1,
        openInterest: 1,
        fundingRatePercent: nil,
        about: nil,
        openEnabled: true
    )
}

private final class GatedMarketDetailsLoadingSpy: PerpsMarketDetailsLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var resumes: [(Result<PerpsAssetMarketSnapshot, Error>) -> Void] = []
    private var waiters: [(needed: Int, resume: () -> Void)] = []

    func load(marketId _: Int64) async throws -> PerpsAssetMarketSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            resumes.append { continuation.resume(with: $0) }
            let count = resumes.count
            let ready = waiters.filter { $0.needed <= count }
            waiters.removeAll { $0.needed <= count }
            lock.unlock()
            ready.forEach { $0.resume() }
        }
    }

    func waitForRequestCount(_ count: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if resumes.count >= count {
                lock.unlock()
                continuation.resume()
                return
            }
            waiters.append((count, { continuation.resume() }))
            lock.unlock()
        }
    }

    func complete(index: Int, with result: Result<PerpsAssetMarketSnapshot, Error>) {
        lock.lock()
        let resume = resumes[index]
        lock.unlock()
        resume(result)
    }
}
