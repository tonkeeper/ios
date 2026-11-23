import BigInt
import Foundation
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import TonSwift
import XCTest

/// A deposit whose source fee the battery's relayer pays: who it is offered to, what is recorded
/// before the relayer is asked, and that nothing handed to it is ever sent a second time.
final class PerpsDepositRelayTests: XCTestCase {
    private var directoryURL: URL!
    private let battery = MultichainSwapFeeOption(cost: .batteryCharges(count: 5, excess: nil, isInsufficient: false))

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsDepositRelayTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    /// A direct deposit is recorded by its gateway call's hash, which a relayed send never learns,
    /// and the relayer carries one call or one batch, never an approval sent before it.
    func testOnlyAnExecutionTrackedSingleCallOrBatchIsOfferedTheRelayer() async throws {
        let engine = RelayStubEngine(chain: .eth, options: [battery])
        let quotes: [(Components.Schemas.DepositQuote, PerpsFundingAsset, Bool)] = [
            (PaymentFixture.relayQuote(), PaymentFixture.ethAsset, true),
            (PaymentFixture.approvedRelayQuote(folded: true), PaymentFixture.usdtFundingAsset, true),
            (PaymentFixture.directQuote(withApproval: false), PerpsDepositService.targetAsset, false),
            (PaymentFixture.approvedRelayQuote(), PaymentFixture.usdtFundingAsset, false),
        ]
        for (quoted, asset, offered) in quotes {
            let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quoted)), engine: engine)
            let review = try await review(service, asset: asset, amount: amount(of: quoted, asset: asset))

            let options = await service.feeOptions(of: review, walletAsset: walletAsset(asset))

            XCTAssertEqual(options, offered ? [battery] : [], quoted.quote_id)
        }
    }

    func testAFoldedDepositIsRelayedAsTheBatchPayloadItWasQuoted() async throws {
        let engine = RelayStubEngine(chain: .eth, options: [battery])
        let quoted = PaymentFixture.approvedRelayQuote(folded: true)
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quoted)), engine: engine)
        let asset = PaymentFixture.usdtFundingAsset
        let review = try await review(service, asset: asset, amount: amount(of: quoted, asset: asset))

        _ = await service.feeOptions(of: review, walletAsset: walletAsset(asset))

        let context = try XCTUnwrap(engine.pricedContexts.first)
        guard case let .evmBatch(batch) = context.payload else { return XCTFail("expected an EVM batch") }
        XCTAssertEqual(batch.chain, .eth)
        XCTAssertEqual(batch.sender, PaymentFixture.sender)
        XCTAssertEqual(batch.payload.id, "p_batch")
        XCTAssertEqual(batch.payload._type, "main")
        XCTAssertEqual(context.payloadId, "p_batch")
        XCTAssertEqual(context.spentSourceAmount, 25_000_000)
    }

    func testAFoldedDepositIsNotReviewedOutsideTheChainsTheSignedDelegateRunsOn() async throws {
        let elsewhere = PerpsSecurityConfig(
            version: 3,
            hermesDelegate: PerpsDepositCalldata.hermesDelegate,
            hermesDelegateChains: ["bsc"],
            changePubKeyContract: KeyRegistrationFixture.changePubKeyContract
        )
        let asset = PaymentFixture.usdtFundingAsset
        let quoted = PaymentFixture.approvedRelayQuote(folded: true)

        let engine = RelayStubEngine(chain: .eth, options: [battery])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quoted)), engine: engine, security: elsewhere)
        do {
            _ = try await review(service, asset: asset, amount: amount(of: quoted, asset: asset))
            XCTFail("read a folded batch outside the signed delegate's chains")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .malformedPayload(payloadId: "p_batch"))
        }
        XCTAssertTrue(engine.pricedContexts.isEmpty)
    }

    func testATonDepositIsRelayedAsTheMessageItWasQuoted() async throws {
        let engine = RelayStubEngine(chain: .ton, options: [battery])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.tonQuote())), engine: engine)
        let review = try await service.review(
            sourceAsset: PaymentFixture.tonAsset,
            amount: "25",
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        _ = await service.feeOptions(of: review, walletAsset: walletAsset(PaymentFixture.tonAsset))

        let context = try XCTUnwrap(engine.pricedContexts.first)
        guard case let .ton(messages) = context.payload else { return XCTFail("expected a TON message") }
        XCTAssertEqual(messages.map(\.amount), [25_000_000_000])
        XCTAssertEqual(context.payloadId, "p_ton")
        XCTAssertFalse(context.requiresApproval)
        XCTAssertEqual(context.spentSourceAmount, 25_000_000_000)
    }

    func testAnOmnistonJettonPaymentIsNeverOfferedTheRelayer() async throws {
        let engine = RelayStubEngine(chain: .ton, options: [battery])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(OmnistonQuote.quote())), engine: engine)
        let review = try await service.review(
            sourceAsset: OmnistonQuote.usdt,
            amount: "25",
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        _ = await service.feeOptions(of: review, walletAsset: walletAsset(OmnistonQuote.usdt))

        XCTAssertTrue(engine.pricedContexts.isEmpty)
    }

    func testATonDepositToAnotherAddressIsNeverOfferedTheRelayer() async throws {
        let engine = RelayStubEngine(chain: .ton, options: [battery])
        var quote = PaymentFixture.tonQuote()
        quote.operation = .transfer([.ton("p_ton", to: TonSwift.Address.mock(workchain: 0, seed: "elsewhere").toString(bounceable: false), value: "25000000000")])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quote)), engine: engine)

        do {
            _ = try await service.review(
                sourceAsset: PaymentFixture.tonAsset,
                amount: "25",
                senderAddress: PaymentFixture.tonSender,
                beneficiary: PaymentFixture.sender,
                registeringKey: false
            )
            XCTFail("a message to another address must not be reviewed")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedTonPayment("destination"))
        }
        XCTAssertTrue(engine.pricedContexts.isEmpty)
    }

    /// The engine emulates before anything is written, so a relay it refuses leaves nothing behind,
    /// and signs only once the payment is journaled, registered, recorded by the backend and marked
    /// as attempted.
    func testARelayedDepositIsPreparedFirstAndRecordedByItsExecutionBeforeTheRelayerIsAskedAndNeverBroadcast() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let paymentJournal = journal()
        let engine = RelayStubEngine(
            chain: .eth,
            options: [battery],
            sendResult: .success(nil),
            onPrepare: {
                let posted = await api.openDepositRequests
                XCTAssertEqual(posted.count, 0, "prepared before the backend records it")
                do {
                    let stored = try await paymentJournal.allFunding()
                    XCTAssertEqual(stored.count, 0, "prepared before it is journaled")
                } catch {
                    XCTFail("the journal could not be read: \(error)")
                }
            },
            onSend: {
                let posted = await api.openDepositRequests
                XCTAssertEqual(posted.map(\.execution_id), ["exec-1"], "recorded before the relayer is asked")
                do {
                    let deposit = try await paymentJournal.funding(operationId: "op-1")?.deposit
                    XCTAssertEqual(deposit?.registration?.operationId, "op-1", "registered before the relayer is asked")
                    XCTAssertEqual(deposit?.relayAttempted, true, "marked before the relayer is asked")
                } catch {
                    XCTFail("the journal could not be read: \(error)")
                }
            }
        )
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, engine: engine)

        let outcome = try await pay(service, api: api, fee: battery)

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        XCTAssertEqual(engine.preparedFees, [.batteryCharges(5)])
        XCTAssertEqual(engine.sentFees, [.batteryCharges(5)])
        XCTAssertEqual(engine.reviewedIntents, [], "nothing is built for a gate without checks")
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
        let stored = try await journal().funding(operationId: "op-1")
        let deposit = try XCTUnwrap(stored?.deposit)
        XCTAssertEqual(deposit.relayAttempted, true)
        XCTAssertEqual(deposit.stage, .registeredPending)
    }

    func testARelayedDepositNamesNoSourceTransaction() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery], sendResult: .success("0xrelayed"))
        let service = makeService(api: api, delivery: StubDepositDelivery(), engine: engine)

        let outcome = try await pay(service, api: api, fee: battery)

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.map(\.source_tx_hash), [nil])
        let stored = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(stored?.deposit?.stage, .registeredPending)
        XCTAssertEqual(stored?.deposit?.sourceTxHash, "0xrelayed")
    }

    func testARelayThatFailsToPrepareLeavesNothingBehindAndAsksForANewQuote() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(
            chain: .eth,
            options: [battery],
            prepareResult: .failure(.preparationFailed(kind: .networkError, reason: "re-priced"))
        )
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, engine: engine)

        do {
            _ = try await pay(service, api: api, fee: battery)
            XCTFail("expected the relay to fail")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        XCTAssertEqual(engine.sentFees, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertTrue(posted.isEmpty)
        let events = await delivery.session.events
        XCTAssertEqual(events, [], "never paid with the chain's own coin instead")
    }

    /// The relayer may still refuse what it prepared once asked to send it.
    func testARelayRefusedWhenSentIsDroppedAndAsksForANewQuote() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(
            chain: .eth,
            options: [battery],
            sendResult: .failure(.preparationFailed(kind: .networkError, reason: "re-priced"))
        )
        let service = makeService(api: api, engine: engine)

        do {
            _ = try await pay(service, api: api, fee: battery)
            XCTFail("expected the relay to fail")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    func testARelayRefusedForLackOfFundsLeavesNothingAndAsksForANewQuote() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(
            chain: .eth,
            options: [battery],
            sendResult: .failure(.broadcastRefused(payloadId: "p_relay", kind: .insufficientBalance, reason: "err-gasless-balance"))
        )
        let service = makeService(api: api, engine: engine)

        do {
            _ = try await pay(service, api: api, fee: battery)
            XCTFail("expected the relay to fail")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    /// Kept, it would be resumed with the chain's own coin instead of the method confirmed.
    func testARelayRefusedBeforeTheRelayerIsAskedLeavesNothingAndIsRelayedWhenConfirmedAgain() async throws {
        let api = FundingStubAPI(openDeposit: .failure(PaymentFixture.addressNotBound), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery])
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, engine: engine)
        let review = try await review(service, asset: PaymentFixture.ethAsset, amount: "0.001")

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: .refuse, relayedFee: battery, walletAsset: walletAsset(PaymentFixture.ethAsset))
            XCTFail("expected the record to fail")
        } catch {
            XCTAssertTrue((error as? PerpsAPIError)?.isAddressNotBound == true)
        }
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        XCTAssertTrue(engine.sentFees.isEmpty)

        await api.setOpenDepositResult(.success(.init(deposit_id: "deposit", status: .pending)))
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse, relayedFee: battery, walletAsset: walletAsset(PaymentFixture.ethAsset))

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        XCTAssertEqual(engine.sentFees.count, 1)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    /// An unanswered relay may still land: it is followed as sent, and paying the same quote
    /// again asks neither the relayer nor the chain a second time.
    func testAnUnansweredRelayIsFollowedAsSentAndNeverSentAgain() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(
            chain: .eth,
            options: [battery],
            sendResult: .failure(.broadcastFailed(payloadId: "p_relay", kind: .networkError, reason: "timeout"))
        )
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, engine: engine)
        let review = try await review(service, asset: PaymentFixture.ethAsset, amount: "0.001")

        let first = try await service.pay(review: review, passcode: "0000", consent: .refuse, relayedFee: battery, walletAsset: walletAsset(PaymentFixture.ethAsset))
        let second = try await service.pay(review: review, passcode: "0000", consent: .refuse, relayedFee: battery, walletAsset: walletAsset(PaymentFixture.ethAsset))

        XCTAssertEqual(first, .registered(operationId: "op-1"))
        XCTAssertEqual(second, .registered(operationId: "op-1"))
        XCTAssertEqual(engine.sentFees.count, 1)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
        let stored = try await journal().funding(operationId: "op-1")
        let deposit = try XCTUnwrap(stored?.deposit)
        XCTAssertEqual(deposit.relayAttempted, true)
    }

    func testAnInsufficientRelayedMethodIsNeverSent() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery], sendResult: .success(nil))
        let service = makeService(api: api, engine: engine)
        let short = MultichainSwapFeeOption(cost: .batteryCharges(count: 5, excess: nil, isInsufficient: true))

        do {
            _ = try await pay(service, api: api, fee: short)
            XCTFail("expected the payment to be refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }
        XCTAssertTrue(engine.sentFees.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertTrue(posted.isEmpty)
    }

    func testARelayInBatteryChargesIsAskedAboutBeforeAnythingIsWrittenAndARefusalRelaysNothing() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery])
        let service = makeService(api: api, engine: engine, checks: [WarningCheck()])
        let review = try await review(service, asset: PaymentFixture.ethAsset, amount: "0.001")
        let user = ConsentingUser(answering: false)

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: user.attempt(), relayedFee: battery, walletAsset: walletAsset(PaymentFixture.ethAsset))
            XCTFail("relayed what the user refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .canceled)
        }

        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertNotEqual(asked.first?.id, review.review?.id, "the relayer's operation, not the payment the quote priced")
        XCTAssertEqual(engine.reviewedIntents, [.wallet(spending: [.init(assetId: PaymentFixture.ethAsset.assetId, symbol: "ETH", decimals: 18, amount: 1_000_000_000_000_000)], to: nil)])
        XCTAssertEqual(engine.preparedFees, [.batteryCharges(5)])
        XCTAssertEqual(engine.sentFees, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertTrue(posted.isEmpty)
    }

    /// A first deposit signs its key registration's documents whatever pays the fee: they are what the
    /// swipe asks about, and the final gate then asks only about the relayer's operation.
    func testARelayedFirstDepositIsAskedAboutItsDocumentsOnTheSwipeAndItsRelayOnceItIsPrepared() async throws {
        let plain = KeyRegistrationFixture.bscFoldedQuote()
        let preview = KeyRegistrationFixture.previewQuote()
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDepositHandler: { request in
                request.change_pub_key != nil && request.operation == nil ? preview : plain
            }
        )
        let engine = RelayStubEngine(chain: .bsc, options: [battery])
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, engine: engine, checks: [WarningCheck()], keyRegistration: KeyRegistrationFixture.registration)
        let asset = KeyRegistrationFixture.bscAsset
        let review = try await service.review(sourceAsset: asset, amount: "25", senderAddress: PaymentFixture.sender, beneficiary: PaymentFixture.sender)
        let documents = try XCTUnwrap(review.review(relayedFee: battery))
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()

        let accepted = await consent(documents)
        let outcome = try await service.pay(review: review, passcode: "0000", consent: consent, relayedFee: battery, walletAsset: walletAsset(asset))

        XCTAssertTrue(accepted)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked.count, 2, "the documents on the swipe, the relayer's operation once prepared")
        XCTAssertEqual(asked.first, documents)
        XCTAssertNotEqual(asked.last?.id, documents.id)
        XCTAssertEqual(engine.sentFees, [.batteryCharges(5)])
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute"])
    }

    /// The checks only shadow a TON relay, and a fee in a token until the backend confirms the
    /// relayer's fee on the payload: what they find is logged and the deposit goes on.
    func testATonRelayIsReviewedWithoutAsking() async throws {
        let engine = RelayStubEngine(chain: .ton, options: [battery])
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.tonQuote()))
        let service = makeService(api: api, engine: engine, checks: [WarningCheck()])
        let review = try await service.review(
            sourceAsset: PaymentFixture.tonAsset,
            amount: "25",
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )
        let user = ConsentingUser(answering: false)
        let log = RecordedLog()
        defer { log.stop() }

        let outcome = try await service.pay(review: review, passcode: "0000", consent: user.attempt(), relayedFee: battery, walletAsset: walletAsset(PaymentFixture.tonAsset))
        let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(engine.reviewedIntents.count, 1)
        XCTAssertEqual(engine.sentFees, [.batteryCharges(5)])
        XCTAssertEqual(logged.count, 1)
    }

    /// Held to the deposit and to the most the relayer's fee may rise to, in the token's own decimals.
    func testARelayPaidInATokenIsReviewedWithoutAsking() async throws {
        let usdt = MultichainAssetDetails(assetId: PaymentFixture.usdtAsset, name: "Tether USD", symbol: "USDT", decimals: 6, image: "")
        let token = MultichainSwapFeeOption(cost: .token(usdt, amount: 120_000, isInsufficient: false))
        let engine = RelayStubEngine(chain: .eth, options: [token])
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let service = makeService(api: api, engine: engine, checks: [WarningCheck()])
        let review = try await review(service, asset: PaymentFixture.ethAsset, amount: "0.001")
        let user = ConsentingUser(answering: false)
        let log = RecordedLog()
        defer { log.stop() }

        let outcome = try await service.pay(review: review, passcode: "0000", consent: user.attempt(), relayedFee: token, walletAsset: walletAsset(PaymentFixture.ethAsset))
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(engine.reviewedIntents, [.wallet(
            spending: [.init(assetId: PaymentFixture.ethAsset.assetId, symbol: "ETH", decimals: 18, amount: 1_000_000_000_000_000)],
            relayerFee: .init(assetId: PaymentFixture.usdtAsset, symbol: "USDT", decimals: 6, amount: 126_000),
            to: nil
        )])
        XCTAssertEqual(engine.sentFees, [.token(assetId: PaymentFixture.usdtAsset, amount: 120_000)])
    }

    func testAClockAheadOfTheRelayerDoesNotRefuseEveryDeposit() async throws {
        let clock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery], expiresAt: clock.now.addingTimeInterval(-30))
        let service = makeService(api: api, engine: engine, clock: clock)

        let outcome = try await pay(service, api: api, fee: battery)

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        XCTAssertEqual(engine.sentFees, [.batteryCharges(5)])
    }

    func testAPayloadThatExpiresInTheEngineIsDroppedAndAsksForANewQuote() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery], sendResult: .failure(.payloadExpired(payloadId: "main")))
        let service = makeService(api: api, engine: engine)

        do {
            _ = try await pay(service, api: api, fee: battery)
            XCTFail("expected the expired payload to fail")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    /// The relayer holds what it prepared to a deadline of its own, which signing must beat by a
    /// moment: one the user read past is never written, let alone sent.
    func testARelayThatLapsesWhileTheUserReadsIsNeverWritten() async throws {
        let clock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.relayQuote()))
        let engine = RelayStubEngine(chain: .eth, options: [battery], expiresAt: clock.now.addingTimeInterval(30))
        let service = makeService(api: api, engine: engine, checks: [WarningCheck()], clock: clock)
        let review = try await review(service, asset: PaymentFixture.ethAsset, amount: "0.001")
        let user = ConsentingUser(answering: true) { clock.advance(by: 26) }

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: user.attempt(), relayedFee: battery, walletAsset: walletAsset(PaymentFixture.ethAsset))
            XCTFail("relayed what its deadline no longer covers")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        XCTAssertEqual(engine.sentFees, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertTrue(posted.isEmpty)
    }

    /// Recorded past the relayer's deadline, the payment is dropped like any other that failed
    /// before the relayer was asked.
    func testARelayThatLapsesWhileItIsRecordedIsDroppedUnsent() async throws {
        let clock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(PaymentFixture.relayQuote()),
            onOpen: { _ in clock.advance(by: 26) }
        )
        let engine = RelayStubEngine(chain: .eth, options: [battery], expiresAt: clock.now.addingTimeInterval(30))
        let service = makeService(api: api, engine: engine, clock: clock)

        do {
            _ = try await pay(service, api: api, fee: battery)
            XCTFail("relayed what its deadline no longer covers")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        XCTAssertEqual(engine.sentFees, [])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.map(\.execution_id), ["exec-1"])
    }

    /// Nothing is left to broadcast, so recovery records it at once instead of waiting for the
    /// quote to lapse — and never takes the empty transmission for a payment that did not go out.
    func testRecoveryRegistersARelayedDepositWithoutReplayingOrFailingIt() async throws {
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: .crosschainSwap,
            beneficiary: PaymentFixture.sender,
            sourceAsset: PaymentFixture.ethAsset,
            sourceAmountUnits: "1000000000000000",
            targetAsset: PerpsDepositService.targetAsset,
            minimumTargetAmountUnits: "2500000",
            executionId: "exec-1",
            registration: .init(operationId: "op-1", assetId: PaymentFixture.ethAsset.assetId, amount: "2.5", l1TxHash: nil, executionId: "exec-1")
        )
        deposit.relayAttempted = true
        deposit.transmission = try PerpsDepositTransmission(
            operation: PerpsDepositOperation(PaymentFixture.relayQuote().operation),
            sender: PaymentFixture.sender,
            expiresAt: Date().addingTimeInterval(600),
            steps: []
        )
        _ = try await journal().saveFundingIfAbsent(.init(operationId: "op-1", walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", details: .deposit(deposit)))
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .credited)))
        let recovery = PerpsFundingRecovery(walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", journal: journal(), api: api, submitLanes: PerpsSubmitLanes(api: api), delivery: delivery, sleep: { _ in })
        let credited = expectation(description: "relayed deposit registered")
        let id = UUID()
        let stream = await recovery.updates(for: id)
        let observer = Task {
            for await state in stream where state.operations.first?.deposit?.stage == .credited {
                credited.fulfill()
                break
            }
        }

        await recovery.setEnabled(true, for: id)
        await fulfillment(of: [credited], timeout: 2)

        let replayed = await delivery.session.replayed
        XCTAssertTrue(replayed.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.map(\.execution_id), ["exec-1"])
        await recovery.removeObserver(id)
        await observer.value
    }

    private func pay(_ service: PerpsDepositService, api _: FundingStubAPI, fee: MultichainSwapFeeOption) async throws -> PerpsDepositOutcome {
        let review = try await review(service, asset: PaymentFixture.ethAsset, amount: "0.001")
        return try await service.pay(review: review, passcode: "0000", consent: .refuse, relayedFee: fee, walletAsset: walletAsset(PaymentFixture.ethAsset))
    }

    private func review(_ service: PerpsDepositService, asset: PerpsFundingAsset, amount: String) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: asset,
            amount: amount,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )
    }

    private func amount(of quoted: Components.Schemas.DepositQuote, asset: PerpsFundingAsset) -> String {
        NSDecimalNumber.fromBigUInt(value: BigUInt(quoted.input.amount) ?? 0, decimals: asset.decimals).stringValue
    }

    private func walletAsset(_ asset: PerpsFundingAsset) -> MultichainAsset {
        MultichainAsset(
            asset: .init(assetId: asset.assetId, name: asset.symbol, symbol: asset.symbol, decimals: asset.decimals, image: ""),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: BigUInt(10).power(asset.decimals + 3)
        )
    }

    private func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "mainnet", directoryURL: directoryURL)
    }

    private func makeService(
        api: FundingStubAPI,
        delivery: StubDepositDelivery = StubDepositDelivery(),
        engine: RelayStubEngine,
        checks: [any OperationCheck] = [],
        keyRegistration: PerpsKeyRegistration? = nil,
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        clock: PaymentClock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))
    ) -> PerpsDepositService {
        PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            gate: OperationGate { checks },
            keyRegistration: { keyRegistration },
            securityConfig: { security },
            relaying: PerpsDepositRelaying(swapWallet: Self.swapWallet, resolver: MultichainSwapFeeMethodResolver(engines: [engine])),
            now: { clock.now },
            makeOperationId: { "op-1" }
        )
    }

    private static let swapWallet: MultichainSwapWallet = {
        let state = MultichainWalletState(
            walletId: "multichain-wallet",
            addresses: [.init(chain: .eth, address: PaymentFixture.sender)]
        )
        let wallet = Wallet(
            id: "wallet",
            identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)),
            metaData: .init(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(state)
        )
        return MultichainSwapWallet(wallet: wallet, registeredState: state)
    }()
}

private final class RelayStubEngine: MultichainSwapRelayedFeeEngine, @unchecked Sendable {
    let chain: MultichainChain
    private(set) var pricedContexts = [MultichainSwapFeeContext]()
    private(set) var preparedFees = [MultichainSwapRelayedFee]()
    private(set) var sentFees = [MultichainSwapRelayedFee]()
    /// The intent each review of what a prepared relay signs was built for.
    private(set) var reviewedIntents = [OperationIntent]()
    private let optionResults: [MultichainSwapFeeOption]
    private let prepareResult: Result<Void, MultichainSwapExecutionFailure>
    private let sendResult: Result<String?, MultichainSwapExecutionFailure>
    private let expiresAt: Date?
    private let onPrepare: () async -> Void
    private let onSend: () async -> Void

    init(
        chain: MultichainChain,
        options: [MultichainSwapFeeOption],
        prepareResult: Result<Void, MultichainSwapExecutionFailure> = .success(()),
        sendResult: Result<String?, MultichainSwapExecutionFailure> = .success(nil),
        expiresAt: Date? = nil,
        onPrepare: @escaping () async -> Void = {},
        onSend: @escaping () async -> Void = {}
    ) {
        self.chain = chain
        optionResults = options
        self.prepareResult = prepareResult
        self.sendResult = sendResult
        self.expiresAt = expiresAt
        self.onPrepare = onPrepare
        self.onSend = onSend
    }

    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        pricedContexts.append(context)
        return optionResults
    }

    func prepare(
        context _: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPreparedRelay {
        await onPrepare()
        try prepareResult.get()
        preparedFees.append(confirmed)
        return MultichainSwapPreparedRelay(
            signables: { intent in
                self.reviewedIntents.append(intent)
                return try [Self.signable(intent: intent)]
            },
            expiresAt: expiresAt,
            send: { _ throws(MultichainSwapExecutionFailure) in
                await self.onSend()
                self.sentFees.append(confirmed)
                return try self.sendResult.get()
            }
        )
    }

    /// The relayer's operation, as chain-kit reads it.
    private static func signable(intent: OperationIntent) throws -> SignableOperation {
        try SignableOperation(
            operation: ChainKitOperationSender.parse(
                id: "relayed",
                payloads: #"[{"chain_id":"eth/mainnet","id":"p_relay","type":"main","version":1,"meta":{"to":"\#(PaymentFixture.relayRouter)","value":"1000"}}]"#
            ),
            account: ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: PaymentFixture.sender), asset: nil),
            intent: intent,
            fidelity: .exact
        )
    }
}
