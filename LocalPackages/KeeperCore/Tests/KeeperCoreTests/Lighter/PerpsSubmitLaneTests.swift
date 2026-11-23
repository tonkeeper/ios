@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsSubmitLaneTests: XCTestCase {
    private actor Trace {
        private(set) var events = [String]()
        private(set) var concurrent = 0
        private(set) var peak = 0

        func enter(_ tag: String) {
            concurrent += 1
            peak = max(peak, concurrent)
            events.append("+\(tag)")
        }

        func leave(_ tag: String) {
            concurrent -= 1
            events.append("-\(tag)")
        }
    }

    private actor VenueNonces {
        private var values: [Int64?]
        private(set) var reads = 0

        init(_ values: [Int64?]) {
            self.values = values
        }

        func next() throws -> Int64 {
            reads += 1
            guard let value = values.count > 1 ? values.removeFirst() : values[0] else {
                throw Unavailable()
            }
            return value
        }
    }

    private struct Unavailable: Error {}

    private let sessionA = PerpsAccountSession(accountIndex: 1, apiKeyIndex: 0)
    private let sessionB = PerpsAccountSession(accountIndex: 1, apiKeyIndex: 1)
    private let otherAccount = PerpsAccountSession(accountIndex: 2, apiKeyIndex: 0)

    private func lane(_ venue: VenueNonces) -> PerpsSubmitLane {
        PerpsSubmitLane(api: AccountStubAPI(account: .init(), onNextNonce: { try await venue.next() }), apiKeyIndex: 3)
    }

    func test_sameLaneRunsOneAtATime() async {
        let lane = lane(VenueNonces([nil]))
        let trace = Trace()

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 8 {
                group.addTask {
                    try? await lane.run {
                        await trace.enter("\(index)")
                        try? await Task.sleep(nanoseconds: 2_000_000)
                        await trace.leave("\(index)")
                    }
                }
            }
        }

        let peak = await trace.peak
        XCTAssertEqual(peak, 1, "two operations must never sign on one api key at the same time")
        let events = await trace.events
        XCTAssertEqual(events.count, 16)
        for pair in stride(from: 0, to: events.count, by: 2) {
            XCTAssertEqual(events[pair].dropFirst(), events[pair + 1].dropFirst(), "sections interleaved")
        }
    }

    func test_oneAccountKeepsOneLane() async {
        let lanes = PerpsSubmitLanes(api: AccountStubAPI(account: .init()))

        let first = await lanes.lane(for: sessionA)
        let again = await lanes.lane(for: PerpsAccountSession(accountIndex: 1, apiKeyIndex: 0))
        let otherKey = await lanes.lane(for: sessionB)

        XCTAssertTrue(first === again)
        XCTAssertFalse(first === otherKey)
    }

    func test_differentApiKeysOfOneAccountDoNotBlockEachOther() async {
        let lanes = PerpsSubmitLanes(api: AccountStubAPI(account: .init()))
        let laneA = await lanes.lane(for: sessionA)
        let laneB = await lanes.lane(for: sessionB)
        let started = expectation(description: "both sections entered")
        started.expectedFulfillmentCount = 2
        let release = expectation(description: "release")

        let first = Task {
            try? await laneA.run {
                started.fulfill()
                await fulfillment(of: [release], timeout: 2)
            }
        }
        let second = Task {
            try? await laneB.run {
                started.fulfill()
            }
        }

        await fulfillment(of: [started], timeout: 2)
        release.fulfill()
        _ = await(first.value, second.value)
    }

    func test_differentAccountsDoNotBlockEachOther() async {
        let lanes = PerpsSubmitLanes(api: AccountStubAPI(account: .init()))
        let laneA = await lanes.lane(for: sessionA)
        let other = await lanes.lane(for: otherAccount)
        let started = expectation(description: "both sections entered")
        started.expectedFulfillmentCount = 2
        let release = expectation(description: "release")

        let first = Task {
            try? await laneA.run {
                started.fulfill()
                await fulfillment(of: [release], timeout: 2)
            }
        }
        let second = Task {
            try? await other.run {
                started.fulfill()
            }
        }

        await fulfillment(of: [started], timeout: 2)
        release.fulfill()
        _ = await(first.value, second.value)
    }

    func test_aThrowingSectionStillReleasesTheLane() async {
        let lane = lane(VenueNonces([nil]))
        struct Boom: Error {}

        do {
            try await lane.run { throw Boom() }
            XCTFail("expected the section to rethrow")
        } catch {}

        let reacquired = Task {
            try? await lane.run { true }
        }
        let value = await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await reacquired.value }
            group.addTask {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        XCTAssertEqual(value, true, "a failed submission must not strand the api key")
    }

    func test_canceledWaiterDoesNotEnterAfterTheLaneIsReleased() async {
        let lane = lane(VenueNonces([nil]))
        let entered = expectation(description: "first entered")
        let release = expectation(description: "release")

        let first = Task {
            try? await lane.run {
                entered.fulfill()
                await fulfillment(of: [release], timeout: 2)
            }
        }
        await fulfillment(of: [entered], timeout: 2)

        let waiter = Task {
            do {
                return try await lane.run { true }
            } catch {
                return false
            }
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        waiter.cancel()
        let waiterResult = await waiter.value
        XCTAssertFalse(waiterResult)

        release.fulfill()
        await first.value
        let reacquired = try? await lane.run { true }
        XCTAssertTrue(reacquired == true)
    }

    func testAPreReadIsTakenOnceByTheSubmitOnItsMarket() async throws {
        let lane = lane(VenueNonces([nil]))
        await lane.preRead(marketId: 1) { Components.Schemas.TradingScreen(open_orders: []) }

        let otherMarket = await lane.takePreRead(marketId: 2)
        XCTAssertNil(otherMarket)
        let taken = await lane.takePreRead(marketId: 1)
        let screen = try await XCTUnwrap(taken).value
        XCTAssertEqual(screen.open_orders?.count, 0)
        let again = await lane.takePreRead(marketId: 1)
        XCTAssertNil(again, "a read plans one submit")
    }

    func testAPreReadBeforeASendIsNotPlannedOn() async {
        let lane = lane(VenueNonces([nil]))
        await lane.preRead(marketId: 1) { Components.Schemas.TradingScreen(open_orders: []) }
        try? await lane.send(walletId: "w", txType: 14, txInfo: "{}", txHash: "0x01")

        let taken = await lane.takePreRead(marketId: 1)
        XCTAssertNil(taken, "the send may have changed what the read shows")
    }

    func testAPreReadThatBeganWhileASendWasInFlightIsNotPlannedOn() async throws {
        let sending = expectation(description: "the send is in flight")
        let (releases, release) = AsyncStream<Void>.makeStream()
        let lane = PerpsSubmitLane(
            api: AccountStubAPI(account: .init(), onSendTransactions: { _, transactions in
                sending.fulfill()
                for await _ in releases {
                    break
                }
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "0x01")])
            }),
            apiKeyIndex: 3
        )
        let send = Task { try await lane.send(walletId: "w", txType: 14, txInfo: "{}", txHash: "0x01") }
        await fulfillment(of: [sending], timeout: 2)

        await lane.preRead(marketId: 1) { Components.Schemas.TradingScreen(open_orders: []) }
        release.finish()
        try await send.value

        let taken = await lane.takePreRead(marketId: 1)
        XCTAssertNil(taken, "the send it overlapped may have changed what the read shows")
    }

    func testADroppedPreReadIsNotPlannedOn() async {
        let lane = lane(VenueNonces([nil]))
        await lane.preRead(marketId: 1) { Components.Schemas.TradingScreen(open_orders: []) }
        await lane.dropPreRead(marketId: 1)

        let taken = await lane.takePreRead(marketId: 1)
        XCTAssertNil(taken)
    }

    func testUsesOneVenueAnchorThenAdvancesLocally() async throws {
        let venue = VenueNonces([5, 99])
        let lane = lane(venue)

        let first = try await lane.nextNonce(walletId: "wallet")
        let second = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(first, 5)
        XCTAssertEqual(second, 6)
        let reads = await venue.reads
        XCTAssertEqual(reads, 1)
    }

    func testACaughtUpLaneSignsItsFirstNonceWithoutAskingTheVenueAgain() async throws {
        let venue = VenueNonces([5, 99])
        let lane = lane(venue)

        await lane.catchUpNonce(walletId: "wallet")
        let first = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(first, 5)
        let reads = await venue.reads
        XCTAssertEqual(reads, 1)
    }

    func testCatchingUpTakesTheVenueNonceAnotherDeviceMovedOn() async throws {
        let venue = VenueNonces([5, 99])
        let lane = lane(venue)
        _ = try await lane.nextNonce(walletId: "wallet")

        await lane.catchUpNonce(walletId: "wallet")
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 99)
        let reads = await venue.reads
        XCTAssertEqual(reads, 2)
    }

    func testCatchingUpDoesNotRewindPastAnAcceptedSendTheVenueHasNotCountedYet() async throws {
        let venue = VenueNonces([5, 5])
        let lane = PerpsSubmitLane(
            api: AccountStubAPI(account: .init(), onNextNonce: { try await venue.next() }, onSendTransactions: { _, transactions in
                .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "0x01")])
            }),
            apiKeyIndex: 3
        )
        let sent = try await lane.nextNonce(walletId: "wallet")
        try await lane.send(walletId: "wallet", txType: 14, txInfo: "{}", txHash: "0x01", nonce: sent)

        await lane.catchUpNonce(walletId: "wallet")
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 6)
    }

    func testSigningAfterAFailedCatchUpStaysAboveAnAcceptedSendTheVenueHasNotCountedYet() async throws {
        let venue = VenueNonces([5, nil, 5])
        let lane = PerpsSubmitLane(
            api: AccountStubAPI(account: .init(), onNextNonce: { try await venue.next() }, onSendTransactions: { _, transactions in
                .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "0x01")])
            }),
            apiKeyIndex: 3
        )
        let sent = try await lane.nextNonce(walletId: "wallet")
        try await lane.send(walletId: "wallet", txType: 14, txInfo: "{}", txHash: "0x01", nonce: sent)

        await lane.catchUpNonce(walletId: "wallet")
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 6)
    }

    func testAResyncStaysAboveAnAcceptedSendTheVenueHasNotCountedYet() async throws {
        let venue = VenueNonces([5, 5])
        let lane = PerpsSubmitLane(
            api: AccountStubAPI(account: .init(), onNextNonce: { try await venue.next() }, onSendTransactions: { _, transactions in
                .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: "0x01")])
            }),
            apiKeyIndex: 3
        )
        let sent = try await lane.nextNonce(walletId: "wallet")
        try await lane.send(walletId: "wallet", txType: 14, txInfo: "{}", txHash: "0x01", nonce: sent)

        try await lane.resyncNonce(walletId: "wallet")
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 6)
    }

    func testACatchUpTheVenueRefusedDropsTheCursorSoSigningReadsItAgain() async throws {
        let lane = lane(VenueNonces([5, nil, 9]))
        _ = try await lane.nextNonce(walletId: "wallet")

        await lane.catchUpNonce(walletId: "wallet")
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 9)
    }

    func testCatchingUpTakesBackANonceIssuedButNeverAccepted() async throws {
        let lane = lane(VenueNonces([5, 5]))
        _ = try await lane.nextNonce(walletId: "wallet")
        _ = try await lane.nextNonce(walletId: "wallet")

        await lane.catchUpNonce(walletId: "wallet")
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 5)
    }

    func testACatchUpTheVenueRefusedLeavesTheSigningToReadIt() async throws {
        let lane = lane(VenueNonces([nil, 7]))

        await lane.catchUpNonce(walletId: "wallet")
        let first = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(first, 7)
    }

    func testAnUnconsumedNonceIsSignedAgainByTheNextStep() async throws {
        let lane = lane(VenueNonces([5, 99]))
        let refused = try await lane.nextNonce(walletId: "wallet")

        await lane.returnUnconsumedNonce(refused)
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 5)
    }

    func testAnUnconsumedNonceIsNotReturnedOnceALaterOneWasIssued() async throws {
        let lane = lane(VenueNonces([5, 99]))
        let refused = try await lane.nextNonce(walletId: "wallet")
        _ = try await lane.nextNonce(walletId: "wallet")

        await lane.returnUnconsumedNonce(refused)
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(next, 7)
    }

    func testResyncMakesTheNextAllocationTheVenueNonce() async throws {
        let lane = lane(VenueNonces([5, 12, 99]))

        _ = try await lane.nextNonce(walletId: "wallet")
        try await lane.resyncNonce(walletId: "wallet")

        let next = try await lane.nextNonce(walletId: "wallet")
        XCTAssertEqual(next, 12)
    }

    func testAReusedNonceIsHandedOutNextWithoutAskingTheVenue() async throws {
        let venue = VenueNonces([5, 12])
        let lane = lane(venue)
        _ = try await lane.nextNonce(walletId: "wallet")

        try await lane.reuseNonce(5)

        let retry = try await lane.nextNonce(walletId: "wallet")
        let after = try await lane.nextNonce(walletId: "wallet")
        XCTAssertEqual(retry, 5)
        XCTAssertEqual(after, 6)
        let reads = await venue.reads
        XCTAssertEqual(reads, 1)
    }

    func testAForgottenCursorIsReadFromTheVenueAgain() async throws {
        let lane = lane(VenueNonces([5, 12]))
        _ = try await lane.nextNonce(walletId: "wallet")

        await lane.forgetNonce()

        let next = try await lane.nextNonce(walletId: "wallet")
        XCTAssertEqual(next, 12)
    }

    func testFailedResyncDropsTheOldCursor() async throws {
        let lane = lane(VenueNonces([5, nil, 20]))
        _ = try await lane.nextNonce(walletId: "wallet")

        do {
            try await lane.resyncNonce(walletId: "wallet")
            XCTFail("resync should fail")
        } catch is Unavailable {
            // Expected: the stale cursor must not survive a failed refresh.
        }

        let next = try await lane.nextNonce(walletId: "wallet")
        XCTAssertEqual(next, 20)
    }

    func testAResyncAfterARefusalDoesNotHandOutANonceIssuedWhileItReadTheVenue() async throws {
        let reading = expectation(description: "the resync reads the venue")
        let (answers, answer) = AsyncStream<Int64>.makeStream()
        let anchor = VenueNonces([5])
        let lane = PerpsSubmitLane(
            api: AccountStubAPI(account: .init(), onNextNonce: {
                if await anchor.reads == 0 { return try await anchor.next() }
                reading.fulfill()
                for await nonce in answers {
                    return nonce
                }
                throw Unavailable()
            }),
            apiKeyIndex: 3
        )

        let refused = try await lane.nextNonce(walletId: "wallet")
        let resync = Task { try await lane.resyncNonce(walletId: "wallet") }
        await fulfillment(of: [reading], timeout: 2)
        let issued = try await lane.nextNonce(walletId: "wallet")
        answer.yield(refused)
        try await resync.value
        let next = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual([refused, issued, next], [5, 6, 7])
    }

    func testAdvancingToVenueNonceNeverReusesOrRollsBackALocalNonce() async throws {
        let lane = lane(VenueNonces([5, 99]))
        _ = try await lane.nextNonce(walletId: "wallet")

        try await lane.advanceNonce(to: 8)
        let first = try await lane.nextNonce(walletId: "wallet")
        try await lane.advanceNonce(to: 6)
        let second = try await lane.nextNonce(walletId: "wallet")

        XCTAssertEqual(first, 8)
        XCTAssertEqual(second, 9)
    }

    func testAnotherApiKeyKeepsItsOwnCursor() async throws {
        let venue = VenueNonces([5, 100])
        let lanes = PerpsSubmitLanes(api: AccountStubAPI(account: .init(), onNextNonce: { try await venue.next() }))

        _ = try await lanes.lane(for: sessionA).nextNonce(walletId: "wallet")
        let first = try await lanes.lane(for: sessionB).nextNonce(walletId: "wallet")

        XCTAssertEqual(first, 100)
    }
}
