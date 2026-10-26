import Foundation
@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsAccountTierUpgraderTests: XCTestCase {
    private let refused = PerpsAPIError.badStatus(.undecoded(400, message: "tier_change_refused"))

    func testAStandardAccountIsMovedToPlusOnce() async {
        let venue = VenueStub([.tier("standard"), .accepted])
        let upgrader = makeUpgrader()

        await ensure(upgrader, venue, .resolve)
        await ensure(upgrader, venue, .resolve)

        let calls = await venue.calls
        XCTAssertEqual(calls, ["read", "change plus"])
    }

    func testAPaidOrUnknownTierIsNeverChanged() async {
        for tier in ["plus", "Premium", "something-new"] {
            let venue = VenueStub([.tier(tier)])
            let upgrader = makeUpgrader()

            await ensure(upgrader, venue, .resolve)
            await ensure(upgrader, venue, .trade)

            let calls = await venue.calls
            XCTAssertEqual(calls, ["read"], tier)
        }
    }

    func testATransientFailureIsRetriedWithinTheSameCheck() async {
        let venue = VenueStub([
            .failure(URLError(.notConnectedToInternet)),
            .tier("standard"), .failure(PerpsAPIError.badStatus(.undecoded(503, message: "unavailable"))),
            .tier("standard"), .accepted,
        ])
        let upgrader = makeUpgrader()

        await ensure(upgrader, venue, .resolve)
        await ensure(upgrader, venue, .resolve)

        let calls = await venue.calls
        XCTAssertEqual(calls, ["read", "read", "change plus", "read", "change plus"])
    }

    func testARefusalWaitsForTheRecheckIntervalOnResolve() async {
        let clock = TestClock()
        let venue = VenueStub([
            .tier("standard"), .failure(refused),
            .failure(PerpsAPIError.badStatus(.undecoded(400, message: "readonly_token_unavailable"))),
            .tier("standard"), .accepted,
        ])
        let upgrader = makeUpgrader(clock: clock)

        await ensure(upgrader, venue, .resolve)
        await ensure(upgrader, venue, .resolve)
        var count = await venue.calls.count
        XCTAssertEqual(count, 2)

        clock.advance(PerpsAccountTierUpgrader.recheckInterval)
        await ensure(upgrader, venue, .resolve)
        count = await venue.calls.count
        XCTAssertEqual(count, 3)

        clock.advance(PerpsAccountTierUpgrader.recheckInterval)
        await ensure(upgrader, venue, .resolve)
        clock.advance(PerpsAccountTierUpgrader.recheckInterval)
        await ensure(upgrader, venue, .resolve)
        count = await venue.calls.count
        XCTAssertEqual(count, 5)
    }

    func testAMissingTradingKeyStopsTheCheckUntilTheNextOne() async {
        let clock = TestClock()
        let venue = VenueStub([
            .tier("standard"), .failure(PerpsTradingError.credentialsRevoked),
            .tier("standard"), .accepted,
        ])
        let upgrader = makeUpgrader(clock: clock)

        await ensure(upgrader, venue, .resolve)
        var calls = await venue.calls
        XCTAssertEqual(calls, ["read", "change plus"])

        clock.advance(PerpsAccountTierUpgrader.recheckInterval)
        await ensure(upgrader, venue, .resolve)
        calls = await venue.calls
        XCTAssertEqual(calls, ["read", "change plus", "read", "change plus"])
    }

    func testActivationAndTradesCheckAtOnceWhileResolvesWait() async {
        let venue = VenueStub([
            .tier("standard"), .failure(refused),
            .tier("standard"), .failure(refused),
            .tier("standard"), .accepted,
        ])
        let upgrader = makeUpgrader()

        await ensure(upgrader, venue, .resolve)
        await ensure(upgrader, venue, .resolve)
        await ensure(upgrader, venue, .activation)
        await ensure(upgrader, venue, .trade)
        await ensure(upgrader, venue, .trade)

        let count = await venue.calls.count
        XCTAssertEqual(count, 6)
    }

    func testATradeWaitsForASlowCheckOnlyBriefly() async {
        let hold = Hold()
        let venue = VenueStub([.tier("standard"), .accepted], hold: hold)
        let upgrader = makeUpgrader(tradeWaitNanoseconds: 50_000_000)
        let safety = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await hold.open()
        }
        defer { safety.cancel() }

        let startedAt = Date()
        await ensure(upgrader, venue, .trade)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1)

        await hold.open()
        await ensure(upgrader, venue, .resolve)
        await ensure(upgrader, venue, .trade)
        let calls = await venue.calls
        XCTAssertEqual(calls, ["read", "change plus"])
    }

    func testConcurrentCallsShareOneCheck() async {
        let venue = VenueStub([.tier("standard"), .accepted])
        let upgrader = makeUpgrader()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 20 {
                group.addTask { await self.ensure(upgrader, venue, .resolve) }
            }
        }

        let count = await venue.calls.count
        XCTAssertEqual(count, 2)
    }

    func testAccountsAreCheckedIndependently() async {
        let venue = VenueStub([.tier("plus"), .tier("plus")])
        let upgrader = makeUpgrader()

        await ensure(upgrader, venue, .resolve, accountIndex: 7)
        await ensure(upgrader, venue, .resolve, accountIndex: 8)
        await ensure(upgrader, venue, .resolve, accountIndex: 7)

        let count = await venue.calls.count
        XCTAssertEqual(count, 2)
    }

    private func ensure(
        _ upgrader: PerpsAccountTierUpgrader,
        _ venue: VenueStub,
        _ trigger: PerpsAccountTierUpgrader.Trigger,
        accountIndex: Int64 = 7
    ) async {
        await upgrader.ensurePlus(
            accountIndex: accountIndex,
            trigger: trigger,
            readTier: { try await venue.read() },
            changeTier: { try await venue.change($0) }
        )
    }

    private func makeUpgrader(
        clock: TestClock = TestClock(),
        tradeWaitNanoseconds: UInt64 = 3_000_000_000
    ) -> PerpsAccountTierUpgrader {
        PerpsAccountTierUpgrader(
            retryDelayNanoseconds: 0,
            tradeWaitNanoseconds: tradeWaitNanoseconds,
            now: { clock.now }
        )
    }
}

private actor VenueStub {
    enum Reply {
        case tier(String)
        case accepted
        case failure(Error)
    }

    private var replies: [Reply]
    private let hold: Hold?
    private(set) var calls: [String] = []

    init(_ replies: [Reply], hold: Hold? = nil) {
        self.replies = replies
        self.hold = hold
    }

    func read() async throws -> String {
        calls.append("read")
        await hold?.wait()
        switch next() {
        case let .tier(tier): return tier
        case let .failure(error): throw error
        case .accepted: throw URLError(.badServerResponse)
        }
    }

    func change(_ tier: String) async throws {
        calls.append("change \(tier)")
        await hold?.wait()
        if case let .failure(error) = next() { throw error }
    }

    private func next() -> Reply {
        replies.isEmpty ? .failure(URLError(.badServerResponse)) : replies.removeFirst()
    }
}

private actor Hold {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func open() {
        isOpen = true
        waiting.forEach { $0.resume() }
        waiting.removeAll()
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)

    var now: Date {
        lock.withLock { current }
    }

    func advance(_ interval: TimeInterval) {
        lock.withLock { current += interval }
    }
}
