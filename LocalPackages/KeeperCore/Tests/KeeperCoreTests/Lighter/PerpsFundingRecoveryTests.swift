import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsFundingRecoveryTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsFundingRecoveryTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func testRestoredSignedPaymentReplaysWithoutUnlockAndRegistersPersistedProof() async throws {
        _ = try await journal().saveFundingIfAbsent(broadcastPayment(expiresAt: Date().addingTimeInterval(60)))
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = PerpsFundingRecovery(walletId: "wallet", walletIdentity: "identity", environment: "test", journal: journal(), api: api, delivery: delivery, sleep: { _ in })
        let credited = expectation(description: "replayed payment registered")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [credited], timeout: 2)
        let replayed = await delivery.session.replayed
        XCTAssertEqual(replayed, ["already-signed"])
        let signatures = await delivery.session.signatures
        XCTAssertTrue(signatures.isEmpty)
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 1)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testARestoredPaymentRefusedWhileTheAccountIsBeingCreatedIsNeverBroadcast() async throws {
        _ = try await journal().saveFundingIfAbsent(broadcastPayment(expiresAt: Date().addingTimeInterval(60), handedOver: false))
        let delivery = StubDepositDelivery()
        delivery.onBroadcast = { XCTFail("a refused payment must not be broadcast") }
        let opened = expectation(description: "recorded before the broadcast")
        let api = FundingStubAPI(openDeposit: .failure(PaymentFixture.accountCreationPending), onOpen: { _ in opened.fulfill() })
        let recovery = PerpsFundingRecovery(walletId: "wallet", walletIdentity: "identity", environment: "test", journal: journal(), api: api, delivery: delivery, sleep: { _ in })
        let dropped = expectation(description: "refused payment dropped")
        dropped.assertForOverFulfill = false
        let (id, observer) = await observe(recovery) { state in
            guard case let .loaded(operations) = state, operations.isEmpty else { return }
            dropped.fulfill()
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [opened], timeout: 2)
        await recovery.refresh()
        await fulfillment(of: [dropped], timeout: 2)

        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let replayed = await delivery.session.replayed
        XCTAssertTrue(replayed.isEmpty)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testARestoredUnboundPaymentWaitsForBindingAndReplaysWithoutUnlock() async throws {
        let original = try await journal().saveFundingIfAbsent(broadcastPayment(expiresAt: Date().addingTimeInterval(60), handedOver: false)).operation
        let delivery = StubDepositDelivery()
        let waiting = expectation(description: "unbound payment waits before broadcast")
        let clock = RecoverySleeper { delay in
            XCTAssertEqual(delay, 10_000_000_000)
            waiting.fulfill()
        }
        let api = FundingStubAPI(
            openDeposit: .failure(PaymentFixture.addressNotBound),
            getDeposit: .success(.init(deposit_id: "deposit", status: .credited))
        )
        let recovery = PerpsFundingRecovery(
            walletId: "wallet", walletIdentity: "identity", environment: "test", journal: journal(), api: api, delivery: delivery,
            sleep: { delay in
                if await api.openDepositRequests.count == 1 { try await clock.sleep(delay) }
            }
        )
        let credited = expectation(description: "bound payment replayed and credited")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [waiting], timeout: 2)
        let stored = try await journal().funding(operationId: "operation")
        XCTAssertEqual(stored, original)
        let beforeBinding = await delivery.session.replayed
        XCTAssertTrue(beforeBinding.isEmpty)

        await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .pending)))
        await clock.advance()
        await fulfillment(of: [credited], timeout: 2)

        let replayed = await delivery.session.replayed
        XCTAssertEqual(replayed, ["already-signed"])
        XCTAssertEqual(delivery.openedSessionCount, 0)
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testAnExpiredPaymentWhoseMainPayloadMayBeOnChainStillPostsItsRegistration() async throws {
        _ = try await journal().saveFundingIfAbsent(broadcastPayment(expiresAt: Date().addingTimeInterval(-60)))
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = PerpsFundingRecovery(walletId: "wallet", walletIdentity: "identity", environment: "test", journal: journal(), api: api, delivery: delivery, sleep: { _ in })
        let watched = expectation(description: "expired payment registered")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { watched.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [watched], timeout: 2)
        let replayed = await delivery.session.replayed
        XCTAssertTrue(replayed.isEmpty)
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.first?.operation_id, "operation")
        await recovery.removeObserver(id)
        await observer.value
    }

    func testRestoredRegistrationCompletesWithoutAnAccountOrTradingKey() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = makeRecovery(api: api)
        let credited = expectation(description: "restored deposit credited")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [credited], timeout: 2)

        let stored = try await journal().funding(operationId: "operation")
        XCTAssertEqual(stored?.deposit?.stage, .credited)
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.operation_id, "operation")
        await recovery.removeObserver(id)
        await observer.value
    }

    func testRestoredUnknownRelayWithdrawalSettlesByExecutionId() async throws {
        let operation = PerpsPendingFundingOperation(
            operationId: "withdraw",
            walletId: "wallet",
            walletIdentity: "identity",
            environment: "test",
            details: .withdraw(.init(
                stage: .unknown,
                accountIndex: 42,
                apiKeyIndex: 1,
                chainId: 304,
                assetIndex: 3,
                routeType: 0,
                amountUnits: "20000000",
                executionId: "execution"
            ))
        )
        _ = try await journal().saveFundingIfAbsent(operation)
        let api = FundingStubAPI(fundingStatus: .success(.init(
            execution_id: "execution", status: .success, tx_hashes: ["0xabc"]
        )))
        let recovery = makeRecovery(api: api)
        let settled = expectation(description: "relay withdrawal settled")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.withdraw?.stage == .settled { settled.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [settled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.l1TxHash, "0xabc")
        let requests = await api.fundingStatusRequests
        XCTAssertEqual(requests, ["execution"])
        await recovery.removeObserver(id)
        await observer.value
    }

    /// A relay that never saw the transfer answers 404 for as long as it is asked, so the
    /// withdrawal would block every later one; past its window it is kept as evidence.
    func testARelayWithdrawalTheRelayNeverSawEndsAfterItsWindow() async throws {
        let createdAt = Int64(Date().timeIntervalSince1970 * 1000) - PerpsFundingRecovery.verdictWindowMillis - 1000
        _ = try await journal().saveFundingIfAbsent(withdrawal(stage: .unknown, executionId: "execution", createdAtMillis: createdAt))
        let api = FundingStubAPI(fundingStatus: .failure(.badStatus(.undecoded(404, message: "unknown execution"))))
        let recovery = makeRecovery(api: api)
        let ended = expectation(description: "relay withdrawal ended")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.withdraw?.stage == .unconfirmed { ended.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [ended], timeout: 2)
        let requests = await api.fundingStatusRequests
        XCTAssertEqual(requests, ["execution"])
        await recovery.removeObserver(id)
        await observer.value
    }

    func testAnAcceptedRelayWithdrawalStillPendingAfterItsWindowStopsBlocking() async throws {
        let createdAt = Int64(Date().timeIntervalSince1970 * 1000) - PerpsFundingRecovery.verdictWindowMillis - 1000
        _ = try await journal().saveFundingIfAbsent(withdrawal(stage: .accepted, executionId: "execution", createdAtMillis: createdAt))
        let api = FundingStubAPI(fundingStatus: .success(.init(execution_id: "execution", status: .pending)))
        let recovery = makeRecovery(api: api)
        let ended = expectation(description: "accepted withdrawal no longer blocks")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.withdraw?.stage == .unconfirmed { ended.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [ended], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.failureReason, "l1_unverified")
        XCTAssertEqual(saved?.withdraw?.stage.isInFlight, false)
        await recovery.removeObserver(id)
        await observer.value
    }

    /// The venue lists a withdrawal only once it took it, so a listed attempt whose response
    /// was lost is past L2 and waits for its payout instead of being replayed.
    func testADirectWithdrawalTheVenueListsIsPastL2DespiteALostResponse() async throws {
        _ = try await journal().saveFundingIfAbsent(withdrawal(stage: .unknown, executionId: nil))
        let api = FundingStubAPI(withdrawals: .success(.init(items: [
            .init(id: "0xABC", _type: .withdrawal, timestamp: Date(), status: "pending"),
        ])))
        let polled = expectation(description: "recovery waits for the payout")
        let recovery = makeRecovery(api: api, sleep: { delay in
            XCTAssertEqual(delay, PerpsFundingRecovery.withdrawPollNanoseconds)
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.stage, .awaitingL1)
        XCTAssertEqual(saved?.withdraw?.withdrawalId, "0xABC")
        XCTAssertEqual(saved?.withdraw?.blocksNewWithdrawal, false)
        XCTAssertEqual(saved?.withdraw?.steps.last?.state, .accepted)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testADirectWithdrawalListedAfterSubmissionRecordsItsId() async throws {
        let operation = withdrawal(stage: .awaitingL1, executionId: nil)
        XCTAssertEqual(operation.withdraw?.blocksNewWithdrawal, false)
        _ = try await journal().saveFundingIfAbsent(operation)
        let api = FundingStubAPI(withdrawals: .success(.init(items: [
            .init(id: "0xABC", _type: .withdrawal, timestamp: Date(), status: "pending"),
        ])))
        let polled = expectation(description: "recovery waits for the payout")
        let recovery = makeRecovery(api: api, sleep: { _ in
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.stage, .awaitingL1)
        XCTAssertEqual(saved?.withdraw?.withdrawalId, "0xABC")
        XCTAssertEqual(saved?.withdraw?.blocksNewWithdrawal, false)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testADirectWithdrawalMatchesTheVenueIdAndL1HashByExecutionTime() async throws {
        for status in ["claimable (secure)", "completed (fast)"] {
            let operation = withdrawal(stage: .awaitingL1, executionId: nil)
            _ = try await journal().saveFundingIfAbsent(operation)
            let executedAt = operation.createdAtMillis + 5000
            let api = FundingStubAPI(withdrawals: .success(.init(items: [
                .init(id: "133067386401", _type: .withdrawal, timestamp: Date(timeIntervalSince1970: Double(executedAt + 200) / 1000), amount: "20.000000", tx_hash: "0xL1", status: status),
                .init(id: "wrong-amount", _type: .withdrawal, timestamp: Date(timeIntervalSince1970: Double(executedAt) / 1000), amount: "21", status: "completed (fast)"),
                .init(id: "old", _type: .withdrawal, timestamp: Date(timeIntervalSince1970: Double(executedAt - 2000) / 1000), amount: "20", status: "completed (fast)"),
            ])))
            let recovery = makeRecovery(api: api, executionTime: { hash in
                XCTAssertEqual(hash, "abc")
                return executedAt
            })
            let settled = expectation(description: status)
            let (id, observer) = await observe(recovery) { state in
                if state.operations.first?.withdraw?.stage == .settled { settled.fulfill() }
            }
            await recovery.setEnabled(true, for: id)
            await fulfillment(of: [settled], timeout: 2)
            let saved = try await journal().funding(operationId: "withdraw")
            XCTAssertEqual(saved?.withdraw?.withdrawalId, "133067386401")
            XCTAssertEqual(saved?.withdraw?.l1TxHash, "0xL1")
            XCTAssertEqual(saved?.withdraw?.steps.last?.state, .accepted)
            await recovery.removeObserver(id)
            await observer.value
            try await journal().removeFunding(operationId: "withdraw")
        }
    }

    func testAPendingSecureWithdrawalWithoutAnL1HashRecordsItsVenueId() async throws {
        let operation = withdrawal(stage: .awaitingL1, executionId: nil)
        _ = try await journal().saveFundingIfAbsent(operation)
        let executedAt = operation.createdAtMillis
        let api = FundingStubAPI(withdrawals: .success(.init(items: [
            .init(id: "133067386401", _type: .withdrawal, timestamp: Date(timeIntervalSince1970: Double(executedAt) / 1000), amount: "20.000000", status: "pending (secure)"),
        ])))
        let polled = expectation(description: "secure payout remains pending")
        let recovery = makeRecovery(api: api, sleep: { _ in
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        }, executionTime: { _ in executedAt })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.withdrawalId, "133067386401")
        XCTAssertEqual(saved?.withdraw?.stage, .awaitingL1)
        XCTAssertNil(saved?.withdraw?.l1TxHash)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testADirectWithdrawalNeverAcceptsAnAmbiguousOrUnrelatedActivity() async throws {
        let operation = withdrawal(stage: .awaitingL1, executionId: nil)
        _ = try await journal().saveFundingIfAbsent(operation)
        let executedAt = operation.createdAtMillis
        let timestamp = Date(timeIntervalSince1970: Double(executedAt) / 1000)
        let api = FundingStubAPI(withdrawals: .success(.init(items: [
            .init(id: "first", _type: .withdrawal, timestamp: timestamp, amount: "20", status: "completed (fast)"),
            .init(id: "second", _type: .withdrawal, timestamp: timestamp, amount: "20", status: "claimable (secure)"),
            .init(id: "wrong-amount", _type: .withdrawal, timestamp: timestamp, amount: "21", status: "completed (fast)"),
            .init(id: "old", _type: .withdrawal, timestamp: timestamp.addingTimeInterval(-2), amount: "20", status: "completed (fast)"),
        ])))
        let polled = expectation(description: "ambiguous withdrawal remains pending")
        let recovery = makeRecovery(api: api, sleep: { _ in
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        }, executionTime: { _ in executedAt })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertNil(saved?.withdraw?.withdrawalId)
        XCTAssertEqual(saved?.withdraw?.stage, .awaitingL1)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testARestoredWithdrawalUsesItsVenueIdWithoutReadingTheL2Transaction() async throws {
        let operation = withdrawal(stage: .awaitingL1, executionId: nil, withdrawalId: "133067386401")
        _ = try await journal().saveFundingIfAbsent(operation)
        let timestamp = Date(timeIntervalSince1970: Double(operation.createdAtMillis + 5000) / 1000)
        let api = FundingStubAPI(withdrawalsHandler: { cursor in
            if cursor == nil {
                return .init(items: [
                    .init(id: "newer", _type: .withdrawal, timestamp: timestamp.addingTimeInterval(5), amount: "20", status: "completed (fast)"),
                ], next_cursor: "older")
            }
            return .init(items: [
                .init(id: "133067386401", _type: .withdrawal, timestamp: timestamp, amount: "20", tx_hash: "0xL1", status: "claimable (secure)"),
            ])
        })
        let recovery = makeRecovery(api: api, executionTime: { _ in
            XCTFail("a stored venue id needs no L2 lookup")
            throw URLError(.notConnectedToInternet)
        })
        let settled = expectation(description: "restored withdrawal is claimable")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.withdraw?.stage == .settled { settled.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [settled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.withdrawalId, "133067386401")
        XCTAssertEqual(saved?.withdraw?.l1TxHash, "0xL1")
        await recovery.removeObserver(id)
        await observer.value
    }

    func testAnUnreachableLighterApiDoesNotHoldTheWithdrawalVerdictWindow() async throws {
        let createdAt = Int64(Date().timeIntervalSince1970 * 1000) - PerpsFundingRecovery.verdictWindowMillis - 1000
        _ = try await journal().saveFundingIfAbsent(withdrawal(stage: .awaitingL1, executionId: nil, createdAtMillis: createdAt))
        let api = FundingStubAPI(withdrawals: .success(.init(items: [
            .init(id: "unrelated", _type: .withdrawal, timestamp: Date(), amount: "20", status: "completed (fast)"),
        ])))
        let recovery = makeRecovery(api: api, executionTime: { _ in throw URLError(.badServerResponse) })
        let ended = expectation(description: "withdrawal ended despite the Lighter failure")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.withdraw?.stage == .unconfirmed { ended.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [ended], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.failureReason, "l1_unverified")
        await recovery.removeObserver(id)
        await observer.value
    }

    func testALighterExecutionTimeIsReadOnlyFromAnExecutedTransaction() throws {
        XCTAssertEqual(try PerpsFundingRecovery.decodeExecutionTime(Data(#"{"code":200,"status":3,"executed_at":1791551450235}"#.utf8)), 1_791_551_450_235)
        for body in [
            #"{"code":21500}"#,
            #"{"code":200,"status":0,"executed_at":1791551450235}"#,
            #"{"code":200,"status":2,"executed_at":0}"#,
            #"{"code":200,"status":2}"#,
        ] {
            XCTAssertNil(try PerpsFundingRecovery.decodeExecutionTime(Data(body.utf8)))
        }
        XCTAssertNil(try PerpsFundingRecovery.decodeExecutionTime(Data(#"{"code":21500,"message":"transaction not found"}"#.utf8), httpStatus: 400))
        XCTAssertThrowsError(try PerpsFundingRecovery.decodeExecutionTime(Data(#"{"code":200,"status":3,"executed_at":1791551450235}"#.utf8), httpStatus: 400))
        XCTAssertThrowsError(try PerpsFundingRecovery.decodeExecutionTime(Data(#"{"code":500}"#.utf8)))
    }

    func testAWithdrawalTimeMatchChecksTheNextPageForAmbiguity() async throws {
        for ambiguous in [false, true] {
            let operation = withdrawal(stage: .awaitingL1, executionId: nil)
            _ = try await journal().saveFundingIfAbsent(operation)
            let executedAt = operation.createdAtMillis
            let timestamp = Date(timeIntervalSince1970: Double(executedAt) / 1000)
            let api = FundingStubAPI(withdrawalsHandler: { cursor in
                if cursor == nil {
                    return .init(items: [
                        .init(id: "first", _type: .withdrawal, timestamp: timestamp, amount: "20", status: "claimable (secure)"),
                    ], next_cursor: "older")
                }
                return .init(items: [
                    .init(id: "second", _type: .withdrawal, timestamp: timestamp.addingTimeInterval(ambiguous ? -0.5 : -2), amount: "20", status: "claimable (secure)"),
                ])
            })
            let checked = expectation(description: "withdrawal pages checked")
            let recovery = makeRecovery(api: api, sleep: { _ in
                XCTAssertTrue(ambiguous)
                checked.fulfill()
                try await Task.sleep(nanoseconds: .max)
            }, executionTime: { _ in executedAt })
            let (id, observer) = await observe(recovery) { state in
                if !ambiguous, state.operations.first?.withdraw?.stage == .settled { checked.fulfill() }
            }
            await recovery.setEnabled(true, for: id)
            await fulfillment(of: [checked], timeout: 2)
            let saved = try await journal().funding(operationId: "withdraw")
            XCTAssertEqual(saved?.withdraw?.stage, ambiguous ? .awaitingL1 : .settled)
            let requests = await api.withdrawalsRequests
            XCTAssertEqual(requests, 2)
            await recovery.removeObserver(id)
            await observer.value
            try await journal().removeFunding(operationId: "withdraw")
        }
    }

    func testAWithdrawalTimeMatchDoesNotAcceptAnIncompleteHistoryWindow() async throws {
        let operation = withdrawal(stage: .awaitingL1, executionId: nil)
        _ = try await journal().saveFundingIfAbsent(operation)
        let executedAt = operation.createdAtMillis
        let timestamp = Date(timeIntervalSince1970: Double(executedAt) / 1000)
        let api = FundingStubAPI(withdrawalsHandler: { cursor in
            let item = Components.Schemas.ActivityItem(
                id: cursor == nil ? "candidate" : "unrelated",
                _type: .withdrawal,
                timestamp: timestamp,
                amount: cursor == nil ? "20" : "21",
                status: "claimable (secure)"
            )
            return .init(items: [item], next_cursor: "more")
        })
        let polled = expectation(description: "truncated history remains pending")
        let recovery = makeRecovery(api: api, sleep: { _ in
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        }, executionTime: { _ in executedAt })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.stage, .awaitingL1)
        XCTAssertNil(saved?.withdraw?.withdrawalId)
        let requests = await api.withdrawalsRequests
        XCTAssertEqual(requests, 5)
        await recovery.removeObserver(id)
        await observer.value
    }

    /// A trade may have spent the nonce after the send went unanswered: the attempt is no longer
    /// replayed, but it is not taken as accepted until the venue's history lists it.
    func testASpentNonceStopsTheReplayWithoutAcceptingTheWithdrawal() async throws {
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        _ = try await journal().saveFundingIfAbsent(withdrawal(
            stage: .unknown,
            executionId: nil,
            createdAtMillis: nowMillis - 60000,
            transactionExpiryUnixMs: nowMillis + 600_000
        ))
        let api = FundingStubAPI(
            nextNonce: .success(.init(account_index: 42, nonce: 8)),
            withdrawals: .success(.init(items: []))
        )
        let polled = expectation(description: "recovery waits for evidence")
        let recovery = makeRecovery(api: api, sleep: { _ in
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)

        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.stage, .unknown)
        XCTAssertEqual(saved?.withdraw?.steps.last?.state, .unknown)
        let nonceRequests = await api.nextNonceRequests
        let sends = await api.sendTransactionsRequests
        XCTAssertEqual(nonceRequests, 1)
        XCTAssertEqual(sends, 0)
        await recovery.removeObserver(id)
        await observer.value
    }

    /// An unanswered question is not an answer that the withdrawal is missing: a failed read
    /// of the history must not end one that may have been paid out.
    func testAnUnreadableHistoryDoesNotEndADirectWithdrawal() async throws {
        let createdAt = Int64(Date().timeIntervalSince1970 * 1000) - PerpsFundingRecovery.verdictWindowMillis - 1000
        _ = try await journal().saveFundingIfAbsent(withdrawal(stage: .awaitingL1, executionId: nil, createdAtMillis: createdAt))
        let api = FundingStubAPI(withdrawals: .failure(.transport(underlying: URLError(.timedOut))))
        let polled = expectation(description: "recovery asks again later")
        let recovery = makeRecovery(api: api, sleep: { _ in
            polled.fulfill()
            try await Task.sleep(nanoseconds: .max)
        })
        let (id, observer) = await observe(recovery) { _ in }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [polled], timeout: 2)
        let saved = try await journal().funding(operationId: "withdraw")
        XCTAssertEqual(saved?.withdraw?.stage, .awaitingL1)
        let requests = await api.withdrawalsRequests
        XCTAssertEqual(requests, 1)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testScopesFilterRemoteWalletLocalIdentityAndEnvironment() async throws {
        for value in [
            operation(id: "remote", walletId: "another"),
            operation(id: "identity", identity: "another"),
            operation(id: "environment", environment: "another"),
            operation(id: "ours", stage: .needsAuthorization),
        ] {
            _ = try await journal().saveFundingIfAbsent(value)
        }
        let api = FundingStubAPI()
        let recovery = makeRecovery(api: api)
        let loaded = expectation(description: "only this scope loaded")
        let (id, observer) = await observe(recovery) { state in
            guard case let .loaded(operations) = state else { return }
            XCTAssertEqual(operations.map(\.operationId), ["ours"])
            loaded.fulfill()
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [loaded], timeout: 2)
        await recovery.removeObserver(id)
        await observer.value
        let requests = await api.openDepositRequests.count
        XCTAssertEqual(requests, 0)
    }

    func testTwoObserversShareOneInFlightRegistration() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let entered = expectation(description: "registration entered")
        let gate = RecoveryGate()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited))) { _ in
            entered.fulfill()
            await gate.wait()
        }
        let recovery = makeRecovery(api: api)
        let credited = expectation(description: "both observers receive credit")
        credited.expectedFulfillmentCount = 2
        let receive: @Sendable (PerpsFundingState) -> Void = { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        let (first, firstTask) = await observe(recovery, receive: receive)
        let (second, secondTask) = await observe(recovery, receive: receive)
        await recovery.setEnabled(true, for: first)
        await fulfillment(of: [entered], timeout: 2)
        await recovery.setEnabled(true, for: second)
        await gate.open()
        await fulfillment(of: [credited], timeout: 2)
        let requests = await api.openDepositRequests.count
        XCTAssertEqual(requests, 1)
        await recovery.removeObserver(first)
        await recovery.removeObserver(second)
        await firstTask.value
        await secondTask.value
    }

    func testPauseResumeWaitsForCancelledTransportAndDiscardsItsLateResult() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let entered = expectation(description: "first request entered")
        let resumed = expectation(description: "resumed request entered")
        let firstGate = RecoveryGate()
        let secondGate = RecoveryGate()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited))) { count in
            if count == 1 {
                entered.fulfill()
                await firstGate.wait()
            } else {
                resumed.fulfill()
                await secondGate.wait()
            }
        }
        let recovery = makeRecovery(api: api)
        let credited = expectation(description: "resumed result applied")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [entered], timeout: 2)
        await recovery.setEnabled(false, for: id)
        await recovery.setEnabled(true, for: id)
        let beforeRelease = await api.openDepositRequests.count
        XCTAssertEqual(beforeRelease, 1)
        await firstGate.open()
        await fulfillment(of: [resumed], timeout: 2)
        let stored = try await journal().funding(operationId: "operation")
        XCTAssertEqual(stored?.deposit?.stage, .registrationPending)
        XCTAssertEqual(stored?.revision, 0)
        await secondGate.open()
        await fulfillment(of: [credited], timeout: 2)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testRetryUsesBackoffAndThePersistedBody() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let waiting = expectation(description: "backoff scheduled")
        let clock = RecoverySleeper { delay in
            XCTAssertEqual(delay, 10_000_000_000)
            waiting.fulfill()
        }
        let api = FundingStubAPI(openDeposit: .failure(.badStatus(.undecoded(503, message: "unavailable"))))
        let recovery = makeRecovery(api: api, sleep: { try await clock.sleep($0) })
        let credited = expectation(description: "retry credited")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [waiting], timeout: 2)
        await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .credited)))
        await clock.advance()
        await fulfillment(of: [credited], timeout: 2)
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
        await recovery.removeObserver(id)
        await observer.value
    }

    /// A 409 is otherwise final, but this one lasts only until the deposit creating the account closes.
    func testARegistrationRefusedWhileTheAccountIsBeingCreatedIsRetried() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let waiting = expectation(description: "backoff scheduled")
        let clock = RecoverySleeper { _ in waiting.fulfill() }
        let pending = PerpsAPIFailure(httpStatus: 409, code: "conflict", message: nil, retryable: false, reason: "account_creation_pending")
        let api = FundingStubAPI(openDeposit: .failure(.badStatus(pending)))
        let recovery = makeRecovery(api: api, sleep: { try await clock.sleep($0) })
        let credited = expectation(description: "retry credited")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [waiting], timeout: 2)
        await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .credited)))
        await clock.advance()
        await fulfillment(of: [credited], timeout: 2)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testAnUnboundRegistrationRetriesItsPersistedBodyAfterBinding() async throws {
        let original = try await journal().saveFundingIfAbsent(operation()).operation
        let waiting = expectation(description: "registration waits for binding")
        let clock = RecoverySleeper { _ in waiting.fulfill() }
        let api = FundingStubAPI(openDeposit: .failure(.badStatus(.init(
            httpStatus: 409, code: "address_not_bound", message: nil, retryable: false, reason: nil
        ))))
        let recovery = makeRecovery(api: api, sleep: { try await clock.sleep($0) })
        let credited = expectation(description: "registration retried after binding")
        let (id, observer) = await observe(recovery) { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [waiting], timeout: 2)
        let stored = try await journal().funding(operationId: "operation")
        XCTAssertEqual(stored, original)

        await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .credited)))
        await clock.advance()
        await fulfillment(of: [credited], timeout: 2)

        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testAdditionalObserverDoesNotInterruptBackoff() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let waiting = expectation(description: "backoff scheduled")
        let interrupted = expectation(description: "additional observer interrupts backoff")
        interrupted.isInverted = true
        let clock = RecoverySleeper(onCancel: { interrupted.fulfill() }, onSleep: { _ in waiting.fulfill() })
        let api = FundingStubAPI(openDeposit: .failure(.badStatus(.undecoded(503, message: "unavailable"))))
        let recovery = makeRecovery(api: api, sleep: { try await clock.sleep($0) })
        let credited = expectation(description: "both observers receive credit after backoff")
        credited.expectedFulfillmentCount = 2
        let receive: @Sendable (PerpsFundingState) -> Void = { state in
            if state.operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        let (first, firstTask) = await observe(recovery, receive: receive)
        await recovery.setEnabled(true, for: first)
        await fulfillment(of: [waiting], timeout: 2)
        await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .credited)))
        let (second, secondTask) = await observe(recovery, receive: receive)
        await recovery.setEnabled(true, for: second)
        await fulfillment(of: [interrupted], timeout: 0.1)
        let requestsBeforeRetry = await api.openDepositRequests.count
        XCTAssertEqual(requestsBeforeRetry, 1)

        await clock.advance()
        await fulfillment(of: [credited], timeout: 2)
        await recovery.removeObserver(first)
        await recovery.removeObserver(second)
        await firstTask.value
        await secondTask.value
    }

    func testUnconfirmedAndAuthorizationRequiredDoNotStartPolling() async throws {
        _ = try await journal().saveFundingIfAbsent(operation(stage: .unconfirmed))
        _ = try await journal().saveFundingIfAbsent(operation(id: "authorize", stage: .needsAuthorization))
        let api = FundingStubAPI()
        let recovery = makeRecovery(api: api, sleep: { _ in XCTFail("no pollable records") })
        let loaded = expectation(description: "parked operations loaded")
        let (id, observer) = await observe(recovery) { state in
            if case let .loaded(operations) = state, operations.count == 2 { loaded.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [loaded], timeout: 2)
        await recovery.removeObserver(id)
        await observer.value
        let reads = await api.getDepositRequests
        XCTAssertEqual(reads, 0)
    }

    func testCorruptJournalIsUnavailableInsteadOfAnEmptyAccount() async throws {
        _ = try await journal().saveFundingIfAbsent(operation())
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil).first)
        try Data("{}".utf8).write(to: file)
        let clock = RecoverySleeper { _ in }
        let recovery = makeRecovery(api: FundingStubAPI(), sleep: { try await clock.sleep($0) })
        let unavailable = expectation(description: "journal unavailable")
        let (id, observer) = await observe(recovery) { state in
            if case .unavailable = state { unavailable.fulfill() }
            if case .loaded = state { XCTFail("corrupt journal must not become loaded") }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [unavailable], timeout: 2)
        await recovery.removeObserver(id)
        await observer.value
        XCTAssertEqual(try FileManager.default.setAsideJournals(of: file), [Data("{}".utf8)])
    }

    func testAnOperationSavedWhileTheWorkerIsIdleWaitsForRefresh() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = makeRecovery(api: api)
        let idle = expectation(description: "nothing to recover yet")
        let credited = expectation(description: "late operation registered")
        let (id, observer) = await observe(recovery) { state in
            guard case let .loaded(operations) = state else { return }
            if operations.isEmpty { idle.fulfill() }
            if operations.first?.deposit?.stage == .credited { credited.fulfill() }
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [idle], timeout: 2)

        _ = try await journal().saveFundingIfAbsent(operation())
        let beforeRefresh = await api.openDepositRequests.count
        XCTAssertEqual(beforeRefresh, 0, "the journal has no change signal: saving alone must not wake the worker")

        await recovery.refresh()
        await fulfillment(of: [credited], timeout: 2)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testExpiredStalledDepositIsCleanedWithoutATradingSession() async throws {
        var expired = operation(stage: .unconfirmed)
        expired.updatedAtMillis = 0
        _ = try await journal().saveFundingIfAbsent(expired)
        let recovery = makeRecovery(api: FundingStubAPI())
        let loaded = expectation(description: "expired evidence removed")
        let (id, observer) = await observe(recovery) { state in
            guard case let .loaded(operations) = state else { return }
            XCTAssertTrue(operations.isEmpty)
            loaded.fulfill()
        }
        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [loaded], timeout: 2)
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        await recovery.removeObserver(id)
        await observer.value
    }

    func testBackoffIsCapped() {
        XCTAssertEqual((0 ... 6).map(PerpsFundingRecovery.pollDelayNanoseconds), [
            5_000_000_000, 10_000_000_000, 20_000_000_000, 30_000_000_000,
            30_000_000_000, 30_000_000_000, 30_000_000_000,
        ])
    }
}

private extension PerpsFundingRecoveryTests {
    /// A direct payment whose gateway call was handed to the network without an answer, or
    /// signed and never handed over, with the proof signed before it left.
    func broadcastPayment(expiresAt: Date, handedOver: Bool = true) throws -> PerpsPendingFundingOperation {
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: .directGateway,
            beneficiary: PaymentFixture.sender,
            sourceAsset: PerpsDepositService.targetAsset,
            sourceAmountUnits: "2500000",
            targetAsset: PerpsDepositService.targetAsset,
            minimumTargetAmountUnits: "2500000",
            sourceTxHash: "0xp_gatewayhash",
            registration: .init(operationId: "operation", assetId: PerpsDepositService.targetAsset.assetId, amount: "2.5", l1TxHash: "0xp_gatewayhash", executionId: nil)
        )
        var signed = ChainKitSignedTransaction(payloadId: "p_gateway", nonce: "7", data: "already-signed", hash: "0xp_gatewayhash", acknowledged: false)
        signed.broadcastAttempted = handedOver
        deposit.transmission = try PerpsDepositTransmission(
            operation: PerpsDepositOperation(PaymentFixture.directQuote(withApproval: false).operation),
            sender: PaymentFixture.sender,
            expiresAt: expiresAt,
            steps: [signed]
        )
        return .init(operationId: "operation", walletId: "wallet", walletIdentity: "identity", environment: "test", details: .deposit(deposit))
    }

    func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "identity", environment: "test", directoryURL: directoryURL)
    }

    func makeRecovery(
        api: PerpsAPI,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { _ in XCTFail("unexpected polling") },
        executionTime: @escaping @Sendable (String) async throws -> Int64? = { _ in nil }
    ) -> PerpsFundingRecovery {
        PerpsFundingRecovery(walletId: "wallet", walletIdentity: "identity", environment: "test", journal: journal(), api: api, sleep: sleep, executionTime: executionTime)
    }

    func observe(
        _ recovery: PerpsFundingRecovery,
        receive: @escaping @Sendable (PerpsFundingState) -> Void
    ) async -> (UUID, Task<Void, Never>) {
        let id = UUID()
        let stream = await recovery.updates(for: id)
        return (id, Task {
            for await state in stream {
                receive(state)
            }
        })
    }

    func withdrawal(
        stage: PerpsWithdrawStage,
        executionId: String?,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        transactionExpiryUnixMs: Int64 = 0,
        withdrawalId: String? = nil
    ) -> PerpsPendingFundingOperation {
        PerpsPendingFundingOperation(
            operationId: "withdraw",
            walletId: "wallet",
            walletIdentity: "identity",
            environment: "test",
            createdAtMillis: createdAtMillis,
            details: .withdraw(.init(
                stage: stage,
                accountIndex: 42,
                apiKeyIndex: 1,
                chainId: 304,
                assetIndex: 3,
                routeType: 0,
                amountUnits: "20000000",
                executionId: executionId,
                steps: [.init(
                    stepId: "step",
                    attemptId: "attempt",
                    nonce: 7,
                    transactionExpiryUnixMs: transactionExpiryUnixMs,
                    txType: 13,
                    txInfo: "{}",
                    txHash: "0xabc",
                    state: .unknown
                )],
                withdrawalId: withdrawalId
            ))
        )
    }

    func operation(
        id: String = "operation",
        walletId: String = "wallet",
        identity: String = "identity",
        environment: String = "test",
        stage: PerpsDepositStage = .registrationPending
    ) -> PerpsPendingFundingOperation {
        let asset = PerpsFundingAsset(assetId: "usdc", symbol: "USDC", decimals: 6)
        return PerpsPendingFundingOperation(
            operationId: id, walletId: walletId, walletIdentity: identity, environment: environment,
            details: .deposit(.init(
                stage: stage, route: .directGateway, beneficiary: "0xabc",
                sourceAsset: asset, sourceAmountUnits: "25000000", targetAsset: asset,
                registration: .init(
                    operationId: id, assetId: asset.assetId, amount: "25", l1TxHash: "0xhash",
                    executionId: nil
                )
            ))
        )
    }
}

actor RecoveryGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

private actor RecoverySleeper {
    private let onSleep: @Sendable (UInt64) -> Void
    private let onCancel: @Sendable () -> Void
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    init(onCancel: @escaping @Sendable () -> Void = {}, onSleep: @escaping @Sendable (UInt64) -> Void) {
        self.onSleep = onSleep
        self.onCancel = onCancel
    }

    func sleep(_ delay: UInt64) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                waiters[id] = continuation
                onSleep(delay)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func advance() {
        let pending = waiters.values
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    private func cancel(_ id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        onCancel()
        waiter.resume(throwing: CancellationError())
    }
}
