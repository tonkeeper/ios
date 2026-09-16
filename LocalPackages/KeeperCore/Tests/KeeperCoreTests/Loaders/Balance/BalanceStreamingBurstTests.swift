import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

/// TK-2837 measured end to end: what a stream of landings actually costs once it has passed through
/// the real loader, throttle, scheduler and rates service on a fake clock. The per-component tests
/// pin the rules; this one pins the number the ticket is about.
///
/// Every step waits on an expectation rather than on a count of yields, so the measurement does not
/// depend on how much other work happens to be draining alongside it.
final class BalanceStreamingBurstTests: XCTestCase {
    /// A stream that keeps arriving rather than one instant: two more landings before every
    /// follow-up. Reloads end up spaced by the throttle interval and requests by the rates freshness
    /// window, so the cost follows the clock rather than the number of updates.
    func test_aStreamOfLandingsIsPacedByTheClockNotByTheUpdateCount() async {
        let context = Context()
        context.becomeActive()

        await context.awaitReload { context.streamingUpdate() }
        var reloadTimes = [context.elapsed]
        for _ in 0 ..< 10 {
            context.streamingUpdate()
            context.streamingUpdate()
            await context.awaitScheduledReload()
            reloadTimes.append(context.elapsed)
        }

        let gaps = zip(reloadTimes, reloadTimes.dropFirst()).map { $1 - $0 }
        XCTAssertEqual(context.reloads, 11, "21 updates produced one reload per throttle window")
        XCTAssertEqual(
            gaps,
            Array(repeating: 5, count: 10),
            "reloads are spaced by the 5s event interval, whatever the update rate"
        )
        XCTAssertEqual(
            context.ratesRequests,
            2,
            "50s of reloads costs two requests, one per 30s freshness window"
        )
    }
}

/// `reloads` counts what the loader decided to spend, `ratesRequests` what actually left for the
/// network — the freshness window sits between the two and takes part in the measurement rather
/// than being stubbed away.
private final class Context {
    let balanceLoader: BalanceLoaderImplementation

    private let clock: BurstTestClock
    private let sleeper: BurstTestSleeper
    private let reloadCounter: BurstCounter
    private let ratesRequestCounter: BurstCounter
    private let wallet: Wallet

    /// The periodic tick sleeps on its own interval; every throttle delay is below it, which is how
    /// the two are told apart.
    private let tickInterval: TimeInterval = 30

    private var updates = [Task<Void, Never>]()

    var reloads: Int {
        reloadCounter.count
    }

    var ratesRequests: Int {
        ratesRequestCounter.count
    }

    var elapsed: TimeInterval {
        clock.elapsed
    }

    init() {
        let clock = BurstTestClock()
        let sleeper = BurstTestSleeper(now: { clock.now() })
        let reloadCounter = BurstCounter()
        let ratesRequestCounter = BurstCounter()

        let ratesService = RatesServiceImplementation(
            fetchRates: { _, _ in
                ratesRequestCounter.increment()
                return Rates(ton: [], usdt: [], jettonRates: [:])
            },
            ratesRepository: BurstRatesRepositoryStub(),
            now: { clock.now() }
        )

        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: BurstKeeperInfoRepositoryStub())
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)

        self.clock = clock
        self.sleeper = sleeper
        self.reloadCounter = reloadCounter
        self.ratesRequestCounter = ratesRequestCounter
        wallet = Wallet(
            id: "balance-loader-burst-test",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
        balanceLoader = BalanceLoaderImplementation(
            walletStore: walletsStore,
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            ratesStore: TonRatesStore(repository: BurstRatesRepositoryStub()),
            ratesService: BurstReloadCountingRatesService(
                underlying: ratesService,
                reloads: reloadCounter
            ),
            walletStateLoaderProvider: { _ in
                fatalError("No wallet is registered, so no per-wallet loader should be requested")
            },
            makeTotalBalanceLoader: { loadWalletBalance in
                TotalBalanceLoaderImplementation(
                    balanceStore: BalanceStore(
                        walletsStore: walletsStore,
                        repository: BurstWalletBalanceRepositoryStub()
                    ),
                    multichainPortfolioStore: MultichainPortfolioStore.makeStub(),
                    loadPortfolioTotal: { _, _, _ in },
                    loadWalletBalance: loadWalletBalance
                )
            },
            now: { clock.now() },
            sleep: { delay in await sleeper.sleep(delay: delay) }
        )
    }

    deinit {
        for update in updates {
            update.cancel()
        }
    }

    func becomeActive() {
        balanceLoader.setQuiet(false, owner: .appLifecycle)
    }

    /// The path a streaming update takes in MainController. Kept so the run the test never lets
    /// finish can be cancelled rather than left waiting on a continuation nobody will resume.
    func streamingUpdate() {
        updates.append(
            Task { [balanceLoader, wallet] in
                await balanceLoader.reloadBalance(wallet: wallet, priority: .background)
            }
        )
    }

    /// Every reload begins by asking for rates, and no per-wallet loader is registered, so a run
    /// stops there — which keeps the counts on the traffic the loader chose to spend.
    func awaitReload(
        _ trigger: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let started = XCTestExpectation(description: "reload started")
        reloadCounter.onIncrement = { started.fulfill() }
        trigger()
        let result = await XCTWaiter().fulfillment(of: [started], timeout: 1)
        reloadCounter.onIncrement = nil
        if result != .completed {
            XCTFail("reload did not start", file: file, line: line)
        }
    }

    /// Waits for the throttle to queue its follow-up, moves the clock to that deadline and lets it
    /// run. Waiting on the registration rather than on elapsed yields is what keeps the schedule
    /// deterministic: a sleep registered after the clock moved would chase its own deadline.
    func awaitScheduledReload(
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        guard let delay = await awaitScheduledDelay(file: file, line: line) else { return }
        clock.advance(by: delay)
        await awaitReload({ sleeper.resume(delay: delay) }, file: file, line: line)
    }

    /// Arms the handler before looking, so a run queued in between is caught by one or the other
    /// rather than falling through the gap and waiting out the timeout for something already there.
    private func awaitScheduledDelay(file: StaticString, line: UInt) async -> TimeInterval? {
        let scheduled = XCTestExpectation(description: "throttle queued a run")
        let tickInterval = tickInterval
        sleeper.onSleep = { delay in
            if delay < tickInterval {
                scheduled.fulfill()
            }
        }
        if sleeper.registeredDelay(shorterThan: tickInterval) == nil {
            _ = await XCTWaiter().fulfillment(of: [scheduled], timeout: 1)
        }
        sleeper.onSleep = nil
        guard let delay = sleeper.registeredDelay(shorterThan: tickInterval) else {
            XCTFail("no follow-up was queued", file: file, line: line)
            return nil
        }
        return delay
    }
}

private final class BurstCounter: @unchecked Sendable {
    var onIncrement: (() -> Void)?

    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func increment() {
        let handler = lock.withLock { () -> (() -> Void)? in
            value += 1
            return onIncrement
        }
        handler?()
    }
}

private final class BurstReloadCountingRatesService: RatesService {
    private let underlying: RatesService
    private let reloads: BurstCounter

    init(underlying: RatesService, reloads: BurstCounter) {
        self.underlying = underlying
        self.reloads = reloads
    }

    func loadRates(jettons: [String], currencies: [Currency]) async throws -> Rates {
        reloads.increment()
        return try await underlying.loadRates(jettons: jettons, currencies: currencies)
    }
}

private final class BurstTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    var elapsed: TimeInterval {
        lock.withLock { offset }
    }

    func now() -> Date {
        Date(timeIntervalSince1970: 1000 + lock.withLock { offset })
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { offset += interval }
    }
}

private final class BurstTestSleeper: @unchecked Sendable {
    var onSleep: ((TimeInterval) -> Void)?

    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var pending = [TimeInterval: [CheckedContinuation<Void, Never>]]()

    init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    func sleep(delay: TimeInterval) async {
        await withCheckedContinuation { continuation in
            let handler = lock.withLock { () -> ((TimeInterval) -> Void)? in
                pending[delay, default: []].append(continuation)
                return onSleep
            }
            handler?(delay)
        }
    }

    func registeredDelay(shorterThan bound: TimeInterval) -> TimeInterval? {
        lock.withLock { pending.filter { !$0.value.isEmpty && $0.key < bound }.keys.min() }
    }

    /// Resumes a sleep registered for exactly this delay, so the periodic tick's own sleep cannot be
    /// mistaken for a throttle's.
    func resume(delay: TimeInterval) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            guard var queue = pending[delay], !queue.isEmpty else { return nil }
            let continuation = queue.removeFirst()
            pending[delay] = queue
            return continuation
        }
        continuation?.resume()
    }
}

private enum BurstStubError: Error {
    case missing
}

private final class BurstKeeperInfoRepositoryStub: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw BurstStubError.missing
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}

private struct BurstWalletBalanceRepositoryStub: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> WalletBalance {
        throw BurstStubError.missing
    }
}

private struct BurstRatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        throw BurstStubError.missing
    }
}
