import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

/// What `pay` does around the side effect it cannot take back — the operation leaving the
/// device — and the registration that makes it show as pending afterwards.
final class PerpsDepositPaymentTests: XCTestCase {
    private var directoryURL: URL!
    private let clock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsDepositPaymentTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testChainKitSignedDataCanBePersistedAndReplayedWithoutChangingBytes() throws {
        let operation = try PerpsDepositOperation(PaymentFixture.directQuote(withApproval: false).operation).parsed()
        let payload = try XCTUnwrap(operation.payloads.first)
        let signed = SignedPayload.Companion.shared.signed(payload: payload, data: "0xdeadbeef")
        let persisted = try JSONDecoder().decode(String.self, from: Data(signed.data.description.utf8))
        let replayed = SignedPayload.Companion.shared.signed(payload: payload, data: persisted)
        XCTAssertEqual(persisted, "0xdeadbeef")
        XCTAssertEqual(signed, replayed)
    }

    func testDeadlineIsCheckedAgainAfterPersistingBeforeBroadcast() async throws {
        var step = ChainKitSignedTransaction(payloadId: "main", nonce: "1", data: "bytes", hash: nil, acknowledged: false)
        let deadline = clock.now.addingTimeInterval(60)
        var attempts = [Bool]()
        do {
            try await ChainKitOperationSender.prepareBroadcast(&step, expiresAt: deadline, now: { self.clock.now }) { saved in
                attempts.append(saved.broadcastAttempted)
                self.clock.advance(by: 61)
            }
            XCTFail("expired payment must not broadcast")
        } catch {
            XCTAssertEqual(error as? ChainKitOperationError, .quoteExpired)
        }
        XCTAssertEqual(attempts, [true, false])
        XCTAssertFalse(step.broadcastAttempted)
    }

    func testApprovalAndDepositAreSentInOneUnlockAndRecordedOnceSent() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)

        let outcome = try await service.pay(review: await review(service), passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_approve,p_gateway"])
        let stored = try await journal().funding(operationId: "op-1")
        let deposit = try XCTUnwrap(stored?.deposit)
        XCTAssertEqual(deposit.stage, .registrationPending)
        XCTAssertEqual(deposit.sourceTxHash, StubDepositSigningSession.hash(of: "p_gateway"))
        XCTAssertEqual(deposit.registration?.l1TxHash, StubDepositSigningSession.hash(of: "p_gateway"))
        XCTAssertNil(deposit.registration?.executionId)
        XCTAssertEqual(deposit.sourceAsset, PerpsDepositService.targetAsset)
    }

    func testPayingTheSameQuoteAgainDoesNotCreateAnotherPayment() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)
        _ = try await service.pay(review: review, passcode: "0000")
        _ = try await service.pay(review: review, passcode: "0000")
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_approve", "p_gateway"])
        let stored = try await journal().allFunding()
        XCTAssertEqual(stored.count, 1)
    }

    func testReviewPricesTheWholeOperation() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)

        let priced = try await review(service)
        XCTAssertEqual(priced.networkFee, "0.000042")
        XCTAssertEqual(priced.networkFeeSymbol, "ETH")

        delivery.feeUnits = nil
        let unpriced = try await review(service)
        XCTAssertNil(unpriced.networkFee)
    }

    func testBindingCompletesBeforeAnyPaymentIsSigned() async throws {
        let gate = PaymentGate()
        let delivery = StubDepositDelivery()
        let service = makeService(
            api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote(withApproval: false))),
            delivery: delivery,
            ensureBinding: { passcode in
                XCTAssertEqual(passcode, "0000")
                await gate.wait()
            }
        )
        let reviewed = try await review(service)
        let payment = Task { try await service.pay(review: reviewed, passcode: "0000") }
        await gate.waitUntilEntered()
        let events = await delivery.session.events
        XCTAssertTrue(events.isEmpty)
        let pending = try await journal().allFunding()
        XCTAssertTrue(pending.isEmpty)
        await gate.open()
        let outcome = try await payment.value
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
    }

    func testBindingFailureCanBeRetriedWithoutSendingAPayment() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote(withApproval: false)))
        let refused = makeService(api: api, delivery: delivery, ensureBinding: { _ in throw PerpsTradingError.validation("binding failed") })
        try await assertThrowsAsync(await refused.pay(review: review(refused), passcode: "0000"))
        let events = await delivery.session.events
        XCTAssertTrue(events.isEmpty)
        let pending = try await journal().allFunding()
        XCTAssertTrue(pending.isEmpty)

        let retried = makeService(api: api, delivery: delivery)
        let outcome = try await retried.pay(review: review(retried), passcode: "0000")
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
    }

    func testJournalWriteFailurePreventsSigningAndBroadcast() async throws {
        try Data("not-a-directory".utf8).write(to: directoryURL)
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)
        try await assertThrowsAsync(await service.pay(review: review, passcode: "0000"))
        let events = await delivery.session.events
        XCTAssertTrue(events.isEmpty)
    }

    func testNothingIsRecordedWhenNothingWasSent() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.failSend(ChainKitOperationError.signingFailed(payloadId: "p_approve", reason: "test"))
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)

        try await assertThrowsAsync(await service.pay(review: review, passcode: "0000"))

        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    func testAmbiguousMainBroadcastKeepsSignedBytesAndRegistersKnownHash() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.failSend(ChainKitOperationError.broadcastFailed(payloadId: "p_gateway", sent: ["0xp_approvehash"], reason: "timeout"))
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let outcome = try await service.pay(review: await review(service), passcode: "0000")
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.registration?.l1TxHash, StubDepositSigningSession.hash(of: "p_gateway"))
        XCTAssertEqual(stored?.deposit?.transmission?.steps.last?.data, "signed:p_gateway")
        XCTAssertEqual(stored?.deposit?.transmission?.steps.last?.acknowledged, false)
    }

    /// A node that refused the payment never let it out: it is not registered as sent, and its
    /// signed bytes stay for a retry once the fee coin is topped up.
    func testAMainBroadcastRefusedForFundsIsNotTakenAsSentAndNamesTheFeeCoin() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.failSend(ChainKitOperationError.insufficientFunds(payloadId: "p_gateway"))
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)

        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("paid")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .insufficientNetworkFee(symbol: "ETH"))
        }

        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .sourcePending)
        XCTAssertEqual(stored?.deposit?.transmission?.steps.last?.data, "signed:p_gateway")
        XCTAssertEqual(stored?.deposit?.transmission?.steps.last?.broadcastAttempted, false)

        await delivery.session.failSend(nil)
        let outcome = try await service.pay(review: review, passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_approve", "p_gateway"])
        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, ["p_approve", "p_gateway", "p_gateway"])
    }

    /// The fee path hands a node's refusal over wrapped in `ChainError.Unknown`.
    func testARefusalForFundsIsRecognizedWrappedOrNot() {
        XCTAssertTrue(ChainKitOperationSender.isInsufficientFunds(NodeError.InsufficientFunds(message: "insufficient funds for gas * price + value")))
        XCTAssertTrue(ChainKitOperationSender.isInsufficientFunds(ChainError.InsufficientFunds(message: "insufficient funds")))
        XCTAssertTrue(ChainKitOperationSender.isInsufficientFunds(ChainError.Unknown(cause: NodeError.InsufficientFunds(message: "gas required exceeds allowance"))))
        XCTAssertFalse(ChainKitOperationSender.isInsufficientFunds(ChainError.Unknown(cause: NodeError.Unauthorized())))
        XCTAssertFalse(ChainKitOperationSender.isInsufficientFunds(nil))
    }

    func testExpiredQuoteAfterApprovalNeverSignsMainAndAllowsNewQuote() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.expireAfterApproval()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        try await assertThrowsAsync(await service.pay(review: await review(service), passcode: "0000"))
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .failed)
        XCTAssertEqual(stored?.deposit?.transmission?.steps.map(\.payloadId), ["p_approve"])
        let pending = try await service.pendingReview()
        XCTAssertNil(pending)
    }

    func testUncertainApprovalResumesIdenticalBytesInsteadOfSigningAgain() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.failSend(ChainKitOperationError.broadcastFailed(payloadId: "p_approve", sent: [], reason: "timeout"))
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let quoted = try await review(service)
        try await assertThrowsAsync(await service.pay(review: quoted, passcode: "0000"))
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .sourcePending)
        try await assertThrowsAsync(await service.pay(review: quoted, passcode: "0000"))
        await delivery.session.failSend(nil)
        let pendingReview = try await service.pendingReview()
        let resumed = try XCTUnwrap(pendingReview)
        _ = try await service.pay(review: resumed, passcode: "0000")
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_approve", "p_gateway"])
    }

    func testCrosschainRegistersItsExecutionBeforeAnythingIsSent() async throws {
        let delivery = StubDepositDelivery()
        let session = delivery.session
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(PaymentFixture.approvedRelayQuote()),
            onOpen: { _ in
                let broadcasts = await session.broadcasts
                XCTAssertEqual(broadcasts, [], "recorded before the approval goes out")
            }
        )
        let service = makeService(api: api, delivery: delivery)

        let outcome = try await service.pay(review: await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25"), passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await session.events
        XCTAssertEqual(events, ["send:p_approve,p_relay"])
        let broadcasts = await session.broadcasts
        XCTAssertEqual(broadcasts, ["p_approve", "p_relay"])
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.map(\.execution_id), ["exec-1"])
        XCTAssertEqual(posted.map(\.l1_tx_hash), [nil])
        let stored = try await journal().funding(operationId: "op-1")
        let deposit = try XCTUnwrap(stored?.deposit)
        XCTAssertEqual(deposit.stage, .registeredPending)
        XCTAssertEqual(deposit.depositId, "deposit")
        XCTAssertEqual(deposit.sourceTxHash, StubDepositSigningSession.hash(of: "p_relay"))
    }

    /// The gateway call is named by its hash, known once it is signed: the record goes between
    /// the signature and the broadcast.
    func testADirectDepositIsRecordedBeforeItsGatewayCallIsBroadcast() async throws {
        let delivery = StubDepositDelivery()
        let session = delivery.session
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(PaymentFixture.directQuote()),
            onOpen: { _ in
                let broadcasts = await session.broadcasts
                XCTAssertEqual(broadcasts, ["p_approve"])
            }
        )
        let service = makeService(api: api, delivery: delivery)

        let outcome = try await service.pay(review: await review(service), passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let broadcasts = await session.broadcasts
        XCTAssertEqual(broadcasts, ["p_approve", "p_gateway"])
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.map(\.l1_tx_hash), [StubDepositSigningSession.hash(of: "p_gateway")])
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .registeredPending)
    }

    /// Another deposit is creating the account: the backend asks that this one never go out.
    func testADepositRefusedWhileTheAccountIsBeingCreatedIsNeverSent() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .failure(PaymentFixture.accountCreationPending),
            quoteDeposit: .success(PaymentFixture.approvedRelayQuote())
        )
        let service = makeService(api: api, delivery: delivery)

        do {
            _ = try await service.pay(review: await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25"), passcode: "0000")
            XCTFail("expected the payment to be refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .accountCreationPending)
        }

        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    /// Recorded only once its approval is out: the deposit failed, and holds nothing back.
    func testADirectDepositRefusedAfterItsApprovalFailsWithoutBlockingAnother() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .failure(PaymentFixture.accountCreationPending),
            quoteDeposit: .success(PaymentFixture.directQuote())
        )
        let service = makeService(api: api, delivery: delivery)

        do {
            _ = try await service.pay(review: await review(service), passcode: "0000")
            XCTFail("expected the payment to be refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .accountCreationPending)
        }

        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, ["p_approve"])
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .failed)
        XCTAssertEqual(stored?.deposit?.failureReason, "account_creation_pending")
        let pending = try await service.pendingReview()
        XCTAssertNil(pending)
    }

    func testAnUnboundDirectDepositKeepsItsApprovalAndResumesAfterBinding() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .failure(PaymentFixture.addressNotBound),
            quoteDeposit: .success(PaymentFixture.directQuote())
        )
        let service = makeService(api: api, delivery: delivery)
        do {
            _ = try await service.pay(review: await review(service), passcode: "0000")
            XCTFail("an unbound deposit must wait for binding")
        } catch {
            XCTAssertTrue((error as? PerpsAPIError)?.isAddressNotBound == true)
        }
        let before = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(before?.deposit?.stage, .sourcePending)
        XCTAssertNil(before?.deposit?.failureReason)
        let sentApproval = await delivery.session.broadcasts
        XCTAssertEqual(sentApproval, ["p_approve"])
        let pending = try await service.pendingReview()
        let resumed = try XCTUnwrap(pending)
        let bound = expectation(description: "bound with the resume passcode")
        let retry = makeService(api: api, delivery: delivery, ensureBinding: { passcode in
            XCTAssertEqual(passcode, "0000")
            await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .pending)))
            bound.fulfill()
        })

        let outcome = try await retry.pay(review: resumed, passcode: "0000")

        await fulfillment(of: [bound], timeout: 1)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, ["p_approve", "p_gateway"])
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_approve", "p_gateway"])
        let requests = await api.openDepositRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
    }

    /// A refusal is one whatever its code, and whether or not its body could be read.
    func testADepositRefusedWithAnUnreadableBodyIsNeverSent() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .failure(.badStatus(.undecoded(409, message: "unreadable error body"))),
            quoteDeposit: .success(PaymentFixture.approvedRelayQuote())
        )
        let service = makeService(api: api, delivery: delivery)

        do {
            _ = try await service.pay(review: await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25"), passcode: "0000")
            XCTFail("expected the payment to be refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .failed)
        }

        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    /// Cancelled while the record was in flight: the transport error that surfaces is no deferral.
    func testACancelledRecordSendsNothing() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .failure(.transport(underlying: URLError(.cancelled))),
            quoteDeposit: .success(PaymentFixture.approvedRelayQuote()),
            onOpen: { _ in withUnsafeCurrentTask { $0?.cancel() } }
        )
        let service = makeService(api: api, delivery: delivery)
        let review = try await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25")

        let payment = Task { try await service.pay(review: review, passcode: "0000") }
        let result = await payment.result

        guard case let .failure(error) = result else { return XCTFail("expected the payment to be cancelled") }
        XCTAssertEqual(PerpsDepositService.message(for: error), .canceled)
        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, [])
    }

    /// A registration built by an earlier attempt that never reached the backend is posted before
    /// the resumed broadcast, and refused the same way.
    func testAResumedPaymentIsRecordedBeforeItIsBroadcast() async throws {
        let registration = PerpsDepositRegistration(
            operationId: "op-1",
            assetId: PerpsDepositService.targetAsset.assetId,
            amount: "2.5",
            l1TxHash: StubDepositSigningSession.hash(of: "p_gateway"),
            executionId: nil
        )
        _ = try await journal().saveFundingIfAbsent(sentPayment(registration: registration, handedOver: false))
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(openDeposit: .failure(PaymentFixture.accountCreationPending))
        let service = makeService(api: api, delivery: delivery)
        let pendingReview = try await service.pendingReview()
        let review = try XCTUnwrap(pendingReview)

        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("expected the payment to be refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .accountCreationPending)
        }

        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    func testAQuoteRefusedWhileTheAccountIsBeingCreatedSaysSo() async throws {
        let service = makeService(api: FundingStubAPI(quoteDeposit: .failure(PaymentFixture.accountCreationPending)))

        do {
            _ = try await review(service)
            XCTFail("expected the quote to be refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .accountCreationPending)
        }
    }

    func testTonSourceIsSentFromTheQuotedAddress() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.tonQuote())), delivery: delivery)
        let review = try await service.review(
            sourceAsset: PaymentFixture.tonAsset,
            amount: "25",
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender
        )
        XCTAssertEqual(review.networkFeeSymbol, "GRAM")

        _ = try await service.pay(review: review, passcode: "0000")

        let senders = await delivery.session.senders
        XCTAssertEqual(senders, [PaymentFixture.tonSender])
    }

    func testAnExpiredQuoteIsNotSent() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)
        clock.advance(by: 120)

        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("expected an expired quote")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }
        let events = await delivery.session.events
        XCTAssertTrue(events.isEmpty)
    }

    func testAQuoteRefusalSaysWhatWouldFixIt() async throws {
        let cases: [(reason: String, minUsdAmount: String?, message: PerpsDepositMessage)] = [
            ("insufficient_balance", nil, .insufficientBalance),
            ("amount_too_low", "2.53", .belowMinimum(usd: "2.53")),
            ("amount_too_low", nil, .belowMinimum(usd: "1")),
        ]
        for (reason, minUsdAmount, message) in cases {
            let refusal = PerpsAPIFailure(
                httpStatus: 400,
                code: "bad_request",
                message: nil,
                retryable: false,
                reason: reason,
                minUsdAmount: minUsdAmount
            )
            let service = makeService(api: FundingStubAPI(quoteDeposit: .failure(.badStatus(refusal))))

            do {
                _ = try await review(service)
                XCTFail("expected the quote to be refused: \(reason)")
            } catch {
                XCTAssertEqual(PerpsDepositService.message(for: error), message, reason)
            }
        }
    }

    func testAQuoteThatExpiresDuringTheUnlockIsNotSent() async throws {
        let delivery = StubDepositDelivery()
        delivery.onOpenSession = { [clock] in clock.advance(by: 120) }
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)

        try await assertThrowsAsync(await service.pay(review: review, passcode: "0000"))

        let events = await delivery.session.events
        XCTAssertTrue(events.isEmpty)
    }

    func testASecondPaymentWhileTheFirstIsUnderwayIsRefused() async throws {
        let gate = PaymentGate()
        let delivery = StubDepositDelivery()
        delivery.onOpenSession = { await gate.wait() }
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)

        let first = Task { try await service.pay(review: review, passcode: "0000") }
        await gate.waitUntilEntered()
        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("expected the second payment to be refused")
        } catch {
            XCTAssertEqual(error as? PerpsDepositServiceError, .paymentInProgress)
        }
        await gate.open()
        _ = try await first.value

        let events = await delivery.session.events
        XCTAssertEqual(events.filter { $0.hasPrefix("send:") }.count, 1)
    }

    /// A retry right after a failed attempt takes its own hold: the attempt before it must not
    /// release that one late.
    func testEveryAttemptReleasesItsRecoveryHoldBeforeItReturns() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.failSend(ChainKitOperationError.broadcastFailed(payloadId: "p_approve", sent: [], reason: "timeout"))
        let recovery = PerpsFundingRecovery(walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", journal: journal(), api: FundingStubAPI(), delivery: delivery, sleep: { _ in })
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery, recovery: recovery)

        try await assertThrowsAsync(await service.pay(review: await review(service), passcode: "0000"))
        var held = await recovery.heldDeposits
        XCTAssertTrue(held.isEmpty)

        await delivery.session.failSend(nil)
        let pendingReview = try await service.pendingReview()
        let resumed = try XCTUnwrap(pendingReview)
        _ = try await service.pay(review: resumed, passcode: "0000")
        held = await recovery.heldDeposits
        XCTAssertTrue(held.isEmpty)
    }

    /// Recovery already replaying the payment finishes first: resuming it then only records the
    /// registration instead of sending beside recovery and racing it for the journal revision.
    func testResumingAPaymentRecoveryIsSendingWaitsForThatPass() async throws {
        let gate = PaymentGate()
        let delivery = StubDepositDelivery()
        delivery.onBroadcast = { await gate.wait() }
        _ = try await journal().saveFundingIfAbsent(sentPayment())
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = PerpsFundingRecovery(walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", journal: journal(), api: api, delivery: delivery, sleep: { _ in })
        let service = makeService(api: api, delivery: delivery, recovery: recovery)
        let pendingReview = try await service.pendingReview()
        let review = try XCTUnwrap(pendingReview)
        let observerId = UUID()
        let updates = await recovery.updates(for: observerId)
        let observer = Task { for await _ in updates {} }
        await recovery.setEnabled(true, for: observerId)
        await gate.waitUntilEntered()

        let payment = Task { try await service.pay(review: review, passcode: "0000") }
        while await recovery.heldDeposits.isEmpty {
            await Task.yield()
        }
        await gate.open()
        let outcome = try await payment.value

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
        let replayed = await delivery.session.replayed
        XCTAssertEqual(replayed, ["signed:p_gateway"])
        await recovery.removeObserver(observerId)
        await observer.value
    }

    /// The pass it waited for may finish the deposit outright, which is its outcome, not a changed payment.
    func testResumingAPaymentRecoveryFinishesWhileItWaitsReportsWhatRecoveryLeft() async throws {
        let gate = PaymentGate()
        let delivery = StubDepositDelivery()
        delivery.onBroadcast = { await gate.wait() }
        let registration = PerpsDepositRegistration(
            operationId: "op-1",
            assetId: PerpsDepositService.targetAsset.assetId,
            amount: "2.5",
            l1TxHash: StubDepositSigningSession.hash(of: "p_gateway"),
            executionId: nil
        )
        _ = try await journal().saveFundingIfAbsent(sentPayment(registration: registration))
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = PerpsFundingRecovery(walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", journal: journal(), api: api, delivery: delivery, sleep: { _ in })
        let service = makeService(api: api, delivery: delivery, recovery: recovery)
        let pendingReview = try await service.pendingReview()
        let review = try XCTUnwrap(pendingReview)
        let observerId = UUID()
        let updates = await recovery.updates(for: observerId)
        let observer = Task { for await _ in updates {} }
        await recovery.setEnabled(true, for: observerId)
        await gate.waitUntilEntered()

        let payment = Task { try await service.pay(review: review, passcode: "0000") }
        while await recovery.heldDeposits.isEmpty {
            await Task.yield()
        }
        await gate.open()
        let outcome = try await payment.value

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .credited)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
        await recovery.removeObserver(observerId)
        await observer.value
    }

    func testTheRegistrationIsPostedWhileItsProofIsFresh() async throws {
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(PaymentFixture.directQuote(withApproval: false))
        )
        let service = makeService(api: api)

        _ = try await service.pay(review: await review(service), passcode: "0000")

        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .registeredPending)
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.count, 1)
    }

    /// The money has left: a registration the backend could not be reached for is recovery's
    /// to retry, never a failure the screen would offer to pay again.
    func testAnUnreachableBackendLeavesTheRegistrationToRecovery() async throws {
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote(withApproval: false))))

        let outcome = try await service.pay(review: await review(service), passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .registrationPending)
    }

    /// A deposit sent without a registration on record resumes by recording it, without
    /// sending another payment.
    func testAParkedDepositResumesByRecordingItWithoutSendingAnother() async throws {
        var parked = try sentPayment()
        guard case var .deposit(deposit) = parked.details else { return XCTFail("not a deposit") }
        deposit.stage = .needsAuthorization
        deposit.sourceTxHash = StubDepositSigningSession.hash(of: "p_gateway")
        parked.details = .deposit(deposit)
        _ = try await journal().saveFundingIfAbsent(parked)
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)))
        let service = makeService(api: api, delivery: delivery, operationId: "op-2")
        let pendingReview = try await service.pendingReview()
        let pending = try XCTUnwrap(pendingReview)
        XCTAssertTrue(pending.resumesPayment)

        let outcome = try await service.pay(review: pending, passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .registeredPending)
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.map(\.operation_id), ["op-1"])
        XCTAssertEqual(posted.map(\.l1_tx_hash), [StubDepositSigningSession.hash(of: "p_gateway")])
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testCrosschainTokenApprovalCanSpendLessThanBudget() async throws {
        for folded in [false, true] {
            var quoted = PaymentFixture.approvedRelayQuote(amountUnits: "91519543", approvalAmountUnits: "91244984", folded: folded)
            quoted.output.amount = "89818617"
            quoted.output.min_amount = "89818617"
            let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quoted)))

            let reviewed = try await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "91.519543")

            XCTAssertEqual(reviewed.sourceAmount, "91.519543")
            XCTAssertEqual(reviewed.creditedAmount, "89.818617")
        }
    }

    func testCrosschainTokenApprovalCanSpendTheWholeBudget() async throws {
        for folded in [false, true] {
            let read = try await quote(PaymentFixture.approvedRelayQuote(folded: folded))
            XCTAssertEqual(read.sourceAmountUnits, "25000000")
        }
    }

    func testCrosschainTokenApprovalMustBePositiveAndWithinBudget() async {
        for folded in [false, true] {
            for amount in ["0", "25000001", (BigUInt(2).power(256) - 1).description] {
                await assertRefused(
                    PaymentFixture.approvedRelayQuote(approvalAmountUnits: amount, folded: folded),
                    .approvalAmountMismatch(payloadId: folded ? "p_batch" : "p_approve", amount: amount)
                )
            }
        }
    }

    func testTronTokenApprovalCanSpendLessThanBudget() async throws {
        let quoted = PaymentFixture.crosschainQuote(
            asset: "tron/mainnet/trc20/" + TronFixture.usdt,
            amount: "91519543",
            sender: TronFixture.sender,
            payloads: [
                .tron("p_approve", to: TronFixture.usdt, data: TronFixture.approve(amountUnits: "91244984")),
                .tron("p_relay", to: TronFixture.router, data: "deadbeef"),
            ]
        )

        let read = try await quote(quoted)

        XCTAssertEqual(read.route, .crosschainSwap)
        XCTAssertEqual(read.sourceAmountUnits, "91519543")
    }

    func testADirectDepositStillRequiresApprovalForItsExactAmount() async {
        let token = PerpsFundingAssetId.usdcEthereum.replacingOccurrences(of: "eth/mainnet/erc20/", with: "")
        for folded in [false, true] {
            var quoted = PaymentFixture.directQuote()
            let approval = HermesBatchFixture.approve(spender: PaymentFixture.gateway, amountUnits: "2499999")
            let main = PaymentFixture.depositCalldata(amountUnits: "2500000")
            quoted.operation = .transfer(folded ? [
                .evm("p_batch", to: PaymentFixture.sender, data: HermesBatchFixture.execute([
                    (token, approval),
                    (PaymentFixture.gateway, main),
                ])),
            ] : [
                .evm("p_approve", to: token, data: approval),
                .evm("p_gateway", to: PaymentFixture.gateway, data: main),
            ])
            await assertRefused(quoted, .approvalAmountMismatch(payloadId: folded ? "p_batch" : "p_approve", amount: "2499999"))
        }
    }

    func testCrosschainTokenCannotApproveUnlimitedSpending() async throws {
        let asset = PerpsFundingAsset(assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7", symbol: "USDT", decimals: 6)
        var quote = PaymentFixture.directQuote()
        quote.input.asset_id = asset.assetId
        quote.tracking = .init(execution_id: "exec-1", status_url: "/funding/status/exec-1")
        quote.operation = .transfer([
            .evm("approve", to: "0xdac17f958d2ee523a2206206994597c13d831ec7", data: HermesBatchFixture.approve(spender: PaymentFixture.relayRouter, amountUnits: (BigUInt(2).power(256) - 1).description)),
            .evm("main", to: PaymentFixture.relayRouter, data: "0xdeadbeef"),
        ])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quote)))
        try await assertThrowsAsync(await review(service, asset: asset))
    }

    func testCrosschainFoldedBatchCannotAddAnUnreviewedCall() async throws {
        let token = "0xdac17f958d2ee523a2206206994597c13d831ec7"
        let asset = PerpsFundingAsset(assetId: "eth/mainnet/erc20/" + token, symbol: "USDT", decimals: 6)
        var quote = PaymentFixture.directQuote()
        quote.input.asset_id = asset.assetId
        quote.tracking = .init(execution_id: "exec-1", status_url: "/funding/status/exec-1")
        quote.operation = .transfer([.evm("batch", to: PaymentFixture.sender, data: HermesBatchFixture.execute([
            (token, HermesBatchFixture.approve(spender: PaymentFixture.relayRouter, amountUnits: "2500000")),
            (PaymentFixture.relayRouter, "0xdeadbeef"),
            (token, "0xdeadbeef"),
        ]), gas: "180000", authorization: HermesBatchFixture.authorization())])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quote)))
        try await assertThrowsAsync(await review(service, asset: asset))
    }

    func testAFoldedDepositIsOneTransactionThatDelegatesTheAccount() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.foldedQuote())), delivery: delivery)

        let review = try await review(service)
        _ = try await service.pay(review: review, passcode: "0000")

        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_batch"])
    }

    func testAFoldedDepositApprovingAnotherSpenderThanItPaysIsRefused() async throws {
        let other = "0x00000000000000000000000000000000000000aa"
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.foldedQuote(spender: other))))

        try await assertThrowsAsync(await review(service))
    }

    /// The account sent something since the quote, so the chain would skip the authorization and
    /// the self-call would only spend the gas.
    func testAFoldedDepositQuotedForAnotherNonceAsksForANewQuote() throws {
        let payload = try XCTUnwrap(PerpsDepositOperation(PaymentFixture.foldedQuote().operation).parsed().payloads.first)

        XCTAssertNoThrow(try ChainKitOperationSender.checkAuthorization(of: payload, nonce: BignumBigInteger(long: 11)))
        XCTAssertThrowsError(try ChainKitOperationSender.checkAuthorization(of: payload, nonce: BignumBigInteger(long: 12))) {
            XCTAssertEqual($0 as? ChainKitOperationError, .staleAuthorization(payloadId: "p_batch"))
            XCTAssertEqual(PerpsDepositService.message(for: $0), .quoteExpired)
        }
    }

    func testAQuoteWithAStepThePaymentWouldNotSignIsRefused() async throws {
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote(extraMain: true))))

        do {
            _ = try await review(service)
            XCTFail("expected the quote to be refused")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedPayloads(["p_approve", "p_gateway", "p_extra"]))
        }
    }

    /// An aggregator's payment is opaque, so the approval in front of it is what bounds it: to
    /// the call it precedes, for the amount quoted.
    func testACrosschainApprovalForAnotherSpenderThanItPaysIsRefused() async throws {
        let other = "0x00000000000000000000000000000000000000aa"
        func quoted(spender: String) -> Components.Schemas.DepositQuote {
            PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [
                .evm("p_approve", to: PaymentFixture.usdt, data: HermesBatchFixture.approve(spender: spender, amountUnits: "25000000")),
                .evm("p_relay", to: PaymentFixture.relayRouter, data: "0xdeadbeef"),
            ])
        }

        let quote = try await quote(quoted(spender: PaymentFixture.relayRouter))
        XCTAssertEqual(quote.payloads.map(\.kind), [.approval, .main])
        await assertRefused(quoted(spender: other), .approvalSpenderMismatch(payloadId: "p_approve", spender: other))
    }

    func testACrosschainFoldedDepositApprovingAnotherSpenderThanItPaysIsRefused() async {
        let other = "0x00000000000000000000000000000000000000aa"
        let folded = PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [.evm(
            "p_batch",
            to: PaymentFixture.sender,
            data: HermesBatchFixture.execute([
                (PaymentFixture.usdt, HermesBatchFixture.approve(spender: other, amountUnits: "25000000")),
                (PaymentFixture.relayRouter, "0xdeadbeef"),
            ]),
            gas: "180000",
            authorization: HermesBatchFixture.authorization()
        )])

        await assertRefused(folded, .approvalSpenderMismatch(payloadId: "p_batch", spender: other))
    }

    /// The calldata names the spender by its 20 bytes, the payload by its base58 address.
    func testATronApprovalIsReadAgainstTheAddressItPays() async throws {
        func quoted(spenderHex: String) -> Components.Schemas.DepositQuote {
            PaymentFixture.crosschainQuote(
                asset: "tron/mainnet/trc20/\(TronFixture.usdt)",
                amount: "25000000",
                sender: TronFixture.sender,
                payloads: [
                    .tron("p_approve", to: TronFixture.usdt, data: TronFixture.approve(spenderHex: spenderHex, amountUnits: "25000000")),
                    .tron("p_pay", to: TronFixture.router, data: "deadbeef"),
                ]
            )
        }
        let other = String(repeating: "0", count: 38) + "aa"

        _ = try await quote(quoted(spenderHex: TronFixture.routerHex))
        await assertRefused(quoted(spenderHex: other), .approvalSpenderMismatch(payloadId: "p_approve", spender: "0x" + other))
    }

    func testABitcoinDepositIsBoundByItsOutputsAlone() async throws {
        let quote = try await quote(PaymentFixture.crosschainQuote(
            asset: "btc/mainnet/coin",
            amount: BtcFixture.deposited,
            sender: BtcFixture.sender,
            payloads: [.btc("p_btc")]
        ))

        XCTAssertEqual(quote.payloads.map(\.kind), [.prebuilt])
    }

    func testAJournalThatCannotRecordTheDepositRefusesItBeforeTheUnlock() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)
        let review = try await review(service)
        try Self.setAside(journalAt: directoryURL)

        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("expected the payment to be refused")
        } catch {
            XCTAssertEqual(error as? PerpsPendingJournalError, .fundingSetAside)
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testJournalFailureDuringUnlockPreventsSigningAndRegistration() async throws {
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(PaymentFixture.directQuote(withApproval: false))
        )
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery)
        let review = try await review(service)
        let directoryURL = try XCTUnwrap(directoryURL)
        delivery.onOpenSession = { try? Self.setAside(journalAt: directoryURL) }

        try await assertThrowsAsync(await service.pay(review: review, passcode: "0000"))
        let signatures = await delivery.session.signatures
        XCTAssertTrue(signatures.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertTrue(posted.isEmpty)
    }

    private func quote(_ quoted: Components.Schemas.DepositQuote) async throws -> PerpsDepositQuote {
        try await makeService(api: FundingStubAPI(quoteDeposit: .success(quoted))).quote(
            sourceAsset: quoted.input.asset_id,
            sourceAmountUnits: quoted.input.amount,
            senderAddress: quoted.input.address,
            beneficiary: PaymentFixture.sender
        )
    }

    private func assertRefused(
        _ quoted: Components.Schemas.DepositQuote,
        _ expected: PerpsDepositCalldataError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await quote(quoted)
            XCTFail("expected the quote to be refused", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PerpsDepositCalldataError, expected, file: file, line: line)
        }
    }

    /// What the journal leaves next to itself once a funding record could not be read.
    private static func setAside(journalAt directoryURL: URL) throws {
        let scope = Data("wallet/test".utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data().write(to: directoryURL.appendingPathComponent("\(scope).json.funding-unreadable.test"))
    }

    private func review(
        _ service: PerpsDepositService,
        asset: PerpsFundingAsset = PerpsDepositService.targetAsset,
        amount: String = "2.5"
    ) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: asset,
            amount: amount,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender
        )
    }

    /// A direct payment whose gateway call was handed to the network without an answer.
    private func sentPayment(registration: PerpsDepositRegistration? = nil, handedOver: Bool = true) throws -> PerpsPendingFundingOperation {
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: .directGateway,
            beneficiary: PaymentFixture.sender,
            sourceAsset: PerpsDepositService.targetAsset,
            sourceAmountUnits: "2500000",
            targetAsset: PerpsDepositService.targetAsset,
            minimumTargetAmountUnits: "2500000"
        )
        var signed = ChainKitSignedTransaction(payloadId: "p_gateway", nonce: "0", data: "signed:p_gateway", hash: StubDepositSigningSession.hash(of: "p_gateway"), acknowledged: false)
        signed.broadcastAttempted = handedOver
        deposit.transmission = try PerpsDepositTransmission(
            operation: PerpsDepositOperation(PaymentFixture.directQuote(withApproval: false).operation),
            sender: PaymentFixture.sender,
            expiresAt: Date().addingTimeInterval(600),
            steps: [signed]
        )
        deposit.registration = registration
        return .init(operationId: "op-1", walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", details: .deposit(deposit))
    }

    private func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    private func makeService(
        api: FundingStubAPI = FundingStubAPI(),
        delivery: StubDepositDelivery = StubDepositDelivery(),
        recovery: PerpsFundingRecovery? = nil,
        operationId: String = "op-1",
        ensureBinding: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) -> PerpsDepositService {
        PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            recovery: recovery,
            keyRegistration: { KeyRegistrationFixture.registration },
            ensureBinding: ensureBinding,
            now: { [clock] in clock.now },
            makeOperationId: { operationId }
        )
    }
}

private final class PaymentClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { current += interval }
    }
}

final class StubDepositDelivery: PerpsDepositDelivery {
    let session = StubDepositSigningSession()
    private(set) var pricedOperations = [PerpsDepositOperation]()
    private(set) var openedSessionCount = 0
    var feeUnits: BigUInt? = 42_000_000_000_000
    var openSessionFailure: Error?
    var onOpenSession: (() async -> Void)?
    var onBroadcast: (() async -> Void)?

    func networkFeeUnits(of operation: PerpsDepositOperation, on _: MultichainChain) async -> BigUInt? {
        pricedOperations.append(operation)
        return feeUnits
    }

    func broadcastLegacy(_: PerpsPendingL1Step, on _: MultichainChain, expiresAt _: Date?) async throws {}

    func broadcast(_ transmission: PerpsDepositTransmission, on _: MultichainChain, persist: (ChainKitSignedTransaction) async throws -> Void) async throws {
        await onBroadcast?()
        await session.recordReplay(transmission.steps.filter { !$0.acknowledged }.map(\.data))
        for var step in transmission.steps where !step.acknowledged {
            step.acknowledged = true
            step.hash = StubDepositSigningSession.hash(of: step.payloadId)
            try await persist(step)
        }
    }

    func openSession(passcode _: String) async throws -> any PerpsDepositSigningSession {
        openedSessionCount += 1
        await onOpenSession?()
        if let openSessionFailure { throw openSessionFailure }
        return session
    }
}

actor PaymentGate {
    private var entered = false
    private var enteredWaiters = [CheckedContinuation<Void, Never>]()
    private var openWaiters = [CheckedContinuation<Void, Never>]()
    private var isOpen = false

    func wait() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}

actor StubDepositSigningSession: PerpsDepositSigningSession {
    private(set) var events = [String]()
    private(set) var senders = [String]()
    private(set) var signatures = [String]()
    private(set) var replayed = [String]()
    private(set) var broadcasts = [String]()

    func recordReplay(_ data: [String]) {
        replayed += data
    }

    private var expiresAfterApproval = false
    private var sendFailure: Error?

    static func hash(of payloadId: String) -> String {
        "0x\(payloadId)hash"
    }

    func failSend(_ error: Error?) {
        sendFailure = error
    }

    func expireAfterApproval() {
        expiresAfterApproval = true
    }

    func send(_ operation: PerpsDepositOperation, on _: MultichainChain, sender: String, expiresAt _: Date, saved: [ChainKitSignedTransaction], persist: (ChainKitSignedTransaction) async throws -> Void) async throws -> [String] {
        if let sendFailure, let chainError = sendFailure as? ChainKitOperationError, case .signingFailed = chainError { throw sendFailure }
        let payloads = try JSONSerialization.jsonObject(with: Data(operation.payloads.utf8)) as? [[String: Any]] ?? []
        let ids = payloads.compactMap { $0["id"] as? String }
        events.append("send:" + ids.joined(separator: ","))
        senders.append(sender)
        for (index, id) in ids.enumerated() {
            if index > 0, expiresAfterApproval { throw ChainKitOperationError.quoteExpired }
            var step: ChainKitSignedTransaction
            if let existing = saved.first(where: { $0.payloadId == id }) {
                step = existing
            } else {
                signatures.append(id)
                step = ChainKitSignedTransaction(payloadId: id, nonce: "\(index)", data: "signed:" + id, hash: Self.hash(of: id), acknowledged: false)
                try await persist(step)
            }
            if step.acknowledged { continue }
            step.broadcastAttempted = true
            broadcasts.append(id)
            try await persist(step)
            if let sendFailure, let chainError = sendFailure as? ChainKitOperationError, case let .broadcastFailed(payloadId, _, _) = chainError, payloadId == id { throw sendFailure }
            if let sendFailure, let chainError = sendFailure as? ChainKitOperationError, case let .insufficientFunds(payloadId) = chainError, payloadId == id {
                step.broadcastAttempted = false
                try await persist(step)
                throw sendFailure
            }
            step.acknowledged = true
            try await persist(step)
        }
        return ids.map(Self.hash(of:))
    }

    /// Signs every document as ChainKit writes it: an object for an EIP-7702 authorization, a
    /// string for anything else.
    func signDocuments(_ operation: PerpsDepositOperation, owner _: String) async throws -> [String: String] {
        let payloads = try JSONSerialization.jsonObject(with: Data(operation.payloads.utf8)) as? [[String: Any]] ?? []
        events.append("sign:" + payloads.compactMap { $0["id"] as? String }.joined(separator: ","))
        var signed = [String: String]()
        for payload in payloads {
            guard let id = payload["id"] as? String, let type = payload["type"] as? String else { continue }
            let data = type == "eip7702/authorization"
                ? #"{"y_parity":1,"r":"0x\#(String(repeating: "a", count: 64))","s":"0x\#(String(repeating: "b", count: 64))"}"#
                : #""0x\#(String(repeating: "c", count: 128))1b""#
            signed[id] = #"{"type":"\#(type)/signed","chain_id":"eth/mainnet","payload_id":"\#(id)","meta":{"data":\#(data)}}"#
        }
        return signed
    }
}

enum PaymentFixture {
    static let sender = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
    static let tonSender = "UQARERERERERERERERERERERERERERERERERERERERERERbvW"
    static let gateway = PerpsDepositCalldata.gatewayAddress
    static let relayRouter = "0x00000000000000000000000000000000000000ef"
    static let usdt = "0xdac17f958d2ee523a2206206994597c13d831ec7"
    static let usdtAsset = "eth/mainnet/erc20/\(usdt)"
    static let ethAsset = PerpsFundingAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)
    static let usdtFundingAsset = PerpsFundingAsset(assetId: usdtAsset, symbol: "USDT", decimals: 6)
    static let accountCreationPending = PerpsAPIError.badStatus(.init(
        httpStatus: 409,
        code: "conflict",
        message: nil,
        retryable: false,
        reason: "account_creation_pending"
    ))
    static let addressNotBound = PerpsAPIError.badStatus(.init(
        httpStatus: 409,
        code: "conflict",
        message: nil,
        retryable: false,
        reason: "address_not_bound"
    ))

    /// An aggregator route that approves its router before the payment on the source chain.
    static func approvedRelayQuote(
        amountUnits: String = "25000000",
        approvalAmountUnits: String? = nil,
        folded: Bool = false
    ) -> Components.Schemas.DepositQuote {
        let approval = HermesBatchFixture.approve(spender: relayRouter, amountUnits: approvalAmountUnits ?? amountUnits)
        return crosschainQuote(asset: usdtAsset, amount: amountUnits, payloads: folded ? [
            .evm("p_batch", to: sender, data: HermesBatchFixture.execute([
                (usdt, approval),
                (relayRouter, "0xdeadbeef"),
            ])),
        ] : [
            .evm("p_approve", to: usdt, data: approval),
            .evm("p_relay", to: relayRouter, data: "0xdeadbeef"),
        ])
    }

    static let tonAsset = PerpsFundingAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9)

    static func directQuote(
        amountUnits: String = "2500000",
        withApproval: Bool = true,
        extraMain: Bool = false
    ) -> Components.Schemas.DepositQuote {
        var payloads = [Components.Schemas.QuotePayload]()
        if withApproval {
            payloads.append(.evm(
                "p_approve",
                to: PerpsFundingAssetId.usdcEthereum.replacingOccurrences(of: "eth/mainnet/erc20/", with: ""),
                data: approveCalldata(amountUnits: amountUnits)
            ))
        }
        payloads.append(.evm("p_gateway", to: gateway, data: depositCalldata(amountUnits: amountUnits)))
        if extraMain {
            payloads.append(.evm("p_extra", to: gateway, data: depositCalldata(amountUnits: amountUnits)))
        }
        return .init(
            quote_id: "q_1",
            provider: "direct",
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(
                asset_id: PerpsFundingAssetId.usdcEthereum,
                amount: amountUnits,
                address: sender
            ),
            output: .init(
                asset_id: PerpsFundingAssetId.usdcEthereum,
                amount: amountUnits,
                min_amount: amountUnits,
                address: sender
            ),
            operation: .transfer(payloads),
            tracking: nil,
            preview: false
        )
    }

    static func relayQuote() -> Components.Schemas.DepositQuote {
        .init(
            quote_id: "q_2",
            provider: "relay",
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(
                asset_id: ethAsset.assetId,
                amount: "1000000000000000",
                address: sender
            ),
            output: .init(
                asset_id: PerpsFundingAssetId.usdcEthereum,
                amount: "2500000",
                min_amount: "2500000",
                address: sender
            ),
            operation: .transfer([.evm("p_relay", to: relayRouter, value: "1000000000000000", data: "0xdeadbeef")]),
            tracking: .init(execution_id: "exec-1", status_url: "/funding/status/exec-1"),
            preview: false
        )
    }

    static func tonQuote() -> Components.Schemas.DepositQuote {
        .init(
            quote_id: "q_ton",
            provider: "relay",
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(asset_id: tonAsset.assetId, amount: "25000000000", address: tonSender),
            output: .init(
                asset_id: PerpsFundingAssetId.usdcEthereum,
                amount: "2500000",
                min_amount: "2500000",
                address: sender
            ),
            operation: .transfer([.ton("p_ton", value: "25000000000")]),
            tracking: .init(execution_id: "exec-1", status_url: "/funding/status/exec-1"),
            preview: false
        )
    }

    static func crosschainQuote(
        asset: String,
        amount: String,
        sender: String = PaymentFixture.sender,
        payloads: [Components.Schemas.QuotePayload]
    ) -> Components.Schemas.DepositQuote {
        .init(
            quote_id: "q_crosschain",
            provider: "relay",
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(asset_id: asset, amount: amount, address: sender),
            output: .init(
                asset_id: PerpsFundingAssetId.usdcEthereum,
                amount: "2500000",
                min_amount: "2500000",
                address: PaymentFixture.sender
            ),
            operation: .transfer(payloads),
            tracking: .init(execution_id: "exec-1", status_url: "/funding/status/exec-1"),
            preview: false
        )
    }

    static func foldedQuote(amountUnits: String = "2500000", spender: String = gateway) -> Components.Schemas.DepositQuote {
        var quote = directQuote(amountUnits: amountUnits)
        let token = PerpsFundingAssetId.usdcEthereum.replacingOccurrences(of: "eth/mainnet/erc20/", with: "")
        quote.operation = .transfer([.evm(
            "p_batch",
            to: sender,
            data: HermesBatchFixture.execute([
                (token, HermesBatchFixture.approve(spender: spender, amountUnits: amountUnits)),
                (gateway, depositCalldata(amountUnits: amountUnits)),
            ]),
            gas: "180000",
            authorization: HermesBatchFixture.authorization()
        )])
        return quote
    }

    private static func approveCalldata(amountUnits: String) -> String {
        HermesBatchFixture.approve(spender: gateway, amountUnits: amountUnits)
    }

    static func depositCalldata(amountUnits: String) -> String {
        let amount = BigUInt(amountUnits, radix: 10) ?? 0
        let hex = String(amount, radix: 16)
        return "0x" + PerpsDepositCalldata.depositSelector
            + String(repeating: "0", count: 24) + sender.dropFirst(2)
            + String(repeating: "0", count: 63) + "3"
            + String(repeating: "0", count: 64)
            + String(repeating: "0", count: 64 - hex.count) + hex
    }
}

private func assertThrowsAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error", file: file, line: line)
    } catch {}
}
