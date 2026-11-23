import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import OperationReviewModels
import TKPerpsAPI
import TonSwift
import XCTest

/// Where a deposit clears what it signs: before anything is written, under the confirm attempt's
/// consent, and without building anything while no check is registered.
final class PerpsDepositGateTests: XCTestCase {
    private var directoryURL: URL!
    private let clock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsDepositGateTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testWithoutChecksACoinPaymentBuildsNothingToReviewAndIsPaidAsBefore() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery)

        let review = try await review(service)
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertNil(review.review)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        XCTAssertEqual(delivery.accountRequests, [])
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_approve,p_gateway"])
    }

    func testACoinPaymentIsAskedAboutOnceBeforeAnythingIsWrittenAndARefusalLeavesNothing() async throws {
        let api = FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote()))
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, checks: [WarningCheck()])
        let review = try await review(service)
        let user = ConsentingUser(answering: false)

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: user.attempt())
            XCTFail("paid what the user refused")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
            XCTAssertEqual(PerpsDepositService.message(for: error), .canceled)
        }

        let preview = try XCTUnwrap(review.review)
        XCTAssertEqual(preview.severity, .warning)
        let asked = await user.asked
        XCTAssertEqual(asked, [preview], "the payment the preview showed")
        XCTAssertEqual(delivery.accountRequests, [PerpsFundingAssetId.usdcEthereum, PerpsFundingAssetId.usdcEthereum], "the spent token's account")
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let posted = await api.openDepositRequests
        XCTAssertTrue(posted.isEmpty)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testAPaymentJournaledWhileTheUserReadsComesFirst() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery, checks: [WarningCheck()])
        let review = try await review(service)
        let earlier = try PerpsPendingFundingOperation(
            operationId: "op-earlier",
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            details: directPayment(signed: ["p_approve"]).details
        )
        let user = ConsentingUser(answering: true) { [journal = journal()] in
            do {
                _ = try await journal.saveFundingIfAbsent(earlier)
            } catch {
                XCTFail("\(error)")
            }
        }

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: user.attempt())
            XCTFail("paid next to a payment started while the user read")
        } catch PerpsDepositServiceError.paymentInProgress {}

        let stored = try await journal().allFunding()
        XCTAssertEqual(stored.map(\.operationId), ["op-earlier"])
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    /// A relayed method signs the relayer's operation instead of the payment the preview read.
    func testAPaymentIsShownOnlyWhileTheChainsOwnCoinPaysIt() async throws {
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: StubDepositDelivery(), checks: [WarningCheck()])
        let review = try await review(service)
        let payment = try XCTUnwrap(review.review)

        XCTAssertEqual(review.review(relayedFee: nil), payment)
        XCTAssertEqual(review.review(relayedFee: MultichainSwapFeeOption(cost: .native([], isInsufficient: false))), payment)
        XCTAssertNil(review.review(relayedFee: MultichainSwapFeeOption(cost: .batteryCharges(count: 5, excess: nil, isInsufficient: false))))
    }

    /// Read from the account of the asset it spends at the address it was quoted from, and held to the
    /// source and amount typed: never the address it credits or what it credits.
    func testAPaymentIsReadFromTheAccountThatSpendsItAndHeldToWhatTheUserTyped() async throws {
        var quote = PaymentFixture.relayQuote()
        quote.input.address = Self.otherSender
        let check = WarningCheck()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quote)), delivery: StubDepositDelivery(), checks: [check])
        let review = try await service.review(
            sourceAsset: PaymentFixture.ethAsset,
            amount: "0.001",
            senderAddress: Self.otherSender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: ConsentingUser(answering: false).attempt())
            XCTFail("paid what the user refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .canceled)
        }

        let read = WarningCheck.Read(address: Self.otherSender, assetId: ChainEthereumMainnet.shared.toAsset().id, intent: Self.ethDeposit)
        let reads = await check.reads.all
        XCTAssertEqual(reads, [read, read], "the preview and the payment")
    }

    func testAPaymentAcceptedOnTheSwipeIsNotAskedAboutAgain() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery, checks: [WarningCheck()])
        let review = try await review(service)
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()

        let accepted = try await consent(XCTUnwrap(review.review))
        let outcome = try await service.pay(review: review, passcode: "0000", consent: consent)

        XCTAssertTrue(accepted)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_approve,p_gateway"])
    }

    func testAQuoteThatExpiresWhileTheUserReadsIsNotPaid() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery, checks: [WarningCheck()])
        let review = try await review(service)
        let user = ConsentingUser(answering: true) { [clock] in clock.advance(by: 120) }

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: user.attempt())
            XCTFail("paid an expired quote")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }

        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    /// Nothing a check could not read is signed, and the screen does not take it for the user's
    /// cancellation.
    func testAPaymentNoCheckCouldReadFailsBeforeAnythingIsWritten() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), delivery: delivery, checks: [FailingCheck()])
        let review = try await review(service)

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: ConsentingUser(answering: true).attempt())
            XCTFail("paid what no check could read")
        } catch {
            guard case .unreviewable? = error as? OperationRefusal else { return XCTFail("\(error)") }
            XCTAssertEqual(PerpsDepositService.message(for: error), .failed)
        }

        XCTAssertNil(review.review)
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testWithoutChecksAResumedPaymentBuildsNothingToReview() async throws {
        _ = try await journal().saveFundingIfAbsent(directPayment(signed: ["p_approve"]))
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(), delivery: delivery)
        let pending = try await service.pendingReview()

        _ = try await service.pay(review: XCTUnwrap(pending), passcode: "0000", consent: .refuse)

        XCTAssertEqual(delivery.accountRequests, [])
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_gateway"])
    }

    /// A refusal signs nothing more and undoes nothing already sent: the payment stays to resume.
    func testAResumedPaymentIsAskedAboutWhatItHasLeftToSign() async throws {
        _ = try await journal().saveFundingIfAbsent(directPayment(signed: ["p_approve"]))
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(), delivery: delivery, checks: [WarningCheck()])
        let pending = try await service.pendingReview()
        let resumed = try XCTUnwrap(pending)
        let refusing = ConsentingUser(answering: false)

        do {
            _ = try await service.pay(review: resumed, passcode: "0000", consent: refusing.attempt())
            XCTFail("resumed what the user refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .canceled)
        }
        var signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, [])
        let kept = try await journal().funding(operationId: "op-1")
        XCTAssertEqual(kept?.deposit?.transmission?.steps.map(\.payloadId), ["p_approve"])

        let accepting = ConsentingUser(answering: true)
        _ = try await service.pay(review: resumed, passcode: "0000", consent: accepting.attempt())

        XCTAssertNil(resumed.review)
        let refused = await refusing.asked
        let accepted = await accepting.asked
        XCTAssertEqual(refused.count, 1)
        XCTAssertEqual(accepted, refused, "the same operation, asked again on another confirmation")
        signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_gateway"])
    }

    func testAResumedPaymentIsReadFromTheAccountThatSpendsItAndHeldToWhatTheUserTyped() async throws {
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: .crosschainSwap,
            beneficiary: PaymentFixture.sender,
            sourceAsset: PaymentFixture.ethAsset,
            sourceAmountUnits: "1000000000000000",
            targetAsset: PerpsDepositService.targetAsset,
            minimumTargetAmountUnits: "2500000",
            executionId: "exec-1"
        )
        deposit.transmission = try PerpsDepositTransmission(
            operation: PerpsDepositOperation(PaymentFixture.relayQuote().operation),
            sender: Self.otherSender,
            expiresAt: clock.now.addingTimeInterval(600),
            steps: []
        )
        _ = try await journal().saveFundingIfAbsent(.init(operationId: "op-1", walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", details: .deposit(deposit)))
        let check = WarningCheck()
        let service = makeService(api: FundingStubAPI(), delivery: StubDepositDelivery(), checks: [check])
        let pending = try await service.pendingReview()
        let resumed = try XCTUnwrap(pending)

        do {
            _ = try await service.pay(review: resumed, passcode: "0000", consent: ConsentingUser(answering: false).attempt())
            XCTFail("resumed what the user refused")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .canceled)
        }

        let reads = await check.reads.all
        XCTAssertEqual(reads, [.init(address: Self.otherSender, assetId: ChainEthereumMainnet.shared.toAsset().id, intent: Self.ethDeposit)])
    }

    func testAResumedPaymentWithEveryPayloadSignedIsNotAskedAbout() async throws {
        _ = try await journal().saveFundingIfAbsent(directPayment(signed: ["p_approve", "p_gateway"]))
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(), delivery: delivery, checks: [WarningCheck()])
        let pending = try await service.pendingReview()
        let user = ConsentingUser(answering: false)

        _ = try await service.pay(review: XCTUnwrap(pending), passcode: "0000", consent: user.attempt())

        let asked = await user.asked
        XCTAssertEqual(asked, [])
        let broadcasts = await delivery.session.broadcasts
        XCTAssertEqual(broadcasts, ["p_gateway"])
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, [])
    }

    func testAResumedPaymentTheRelayerHasIsNotAskedAbout() async throws {
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
            expiresAt: clock.now.addingTimeInterval(600),
            steps: []
        )
        _ = try await journal().saveFundingIfAbsent(.init(operationId: "op-1", walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", details: .deposit(deposit)))
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)))
        let service = makeService(api: api, delivery: delivery, checks: [WarningCheck()])
        let pending = try await service.pendingReview()
        let user = ConsentingUser(answering: false)

        let outcome = try await service.pay(review: XCTUnwrap(pending), passcode: "0000", consent: user.attempt())

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    /// The wallet's own address, with the key it stores, holding the asset spent; an address the
    /// wallet does not hold is refused rather than read.
    func testTheDeliveryReadsTheSpentAssetAtTheWalletsOwnAddress() throws {
        let address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
        let key = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")
        let delivery = PerpsChainKitDepositDelivery(
            client: CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
                isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil
            ))),
            mnemonicAccess: .inMemory(seed: "deposit-delivery"),
            wallet: Wallet(
                id: "wallet",
                identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)),
                metaData: .init(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
                setupSettings: .init(isSetupFinished: true),
                batterySettings: .init(),
                multichain: .multichain(.init(walletId: "multichain-wallet", addresses: [.init(chain: .eth, address: address, publicKey: key)]))
            )
        )

        let usdc = try delivery.account(of: PerpsDepositService.targetAsset, on: .eth, sender: address.lowercased())
        let eth = try delivery.account(of: nil, on: .eth, sender: address)

        XCTAssertEqual(usdc.asset.id, PerpsFundingAssetId.usdcEthereum)
        XCTAssertEqual(eth.asset.id, ChainEthereumMainnet.shared.toAsset().id)
        for account in [usdc, eth] {
            XCTAssertEqual(account.addressDisplay.lowercased(), address.lowercased())
            XCTAssertEqual(account.publicKey?.defaultHex, key.defaultHex)
        }
        XCTAssertThrowsError(try delivery.account(of: PerpsDepositService.targetAsset, on: .eth, sender: PaymentFixture.sender)) { error in
            XCTAssertEqual(error as? ChainKitOperationError, .keyMismatch(expected: PaymentFixture.sender, unlocked: usdc.addressDisplay))
        }
    }

    private static let otherSender = "0x00000000000000000000000000000000000000aa"
    /// 0.001 ETH, as `PaymentFixture.relayQuote()` spends it.
    private static let ethDeposit = OperationIntent.wallet(
        spending: [.init(assetId: PaymentFixture.ethAsset.assetId, symbol: "ETH", decimals: 18, amount: 1_000_000_000_000_000)],
        to: nil
    )

    /// A direct payment journaled once the payloads in `signed` were signed and sent.
    private func directPayment(signed: [String]) throws -> PerpsPendingFundingOperation {
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: .directGateway,
            beneficiary: PaymentFixture.sender,
            sourceAsset: PerpsDepositService.targetAsset,
            sourceAmountUnits: "2500000",
            targetAsset: PerpsDepositService.targetAsset,
            minimumTargetAmountUnits: "2500000"
        )
        deposit.transmission = try PerpsDepositTransmission(
            operation: PerpsDepositOperation(PaymentFixture.directQuote().operation),
            sender: PaymentFixture.sender,
            expiresAt: clock.now.addingTimeInterval(600),
            steps: signed.enumerated().map { nonce, payloadId in
                var step = ChainKitSignedTransaction(
                    payloadId: payloadId,
                    nonce: "\(nonce)",
                    data: "signed:\(payloadId)",
                    hash: StubDepositSigningSession.hash(of: payloadId),
                    acknowledged: payloadId != "p_gateway"
                )
                step.broadcastAttempted = true
                return step
            }
        )
        return .init(operationId: "op-1", walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", details: .deposit(deposit))
    }

    private func review(_ service: PerpsDepositService) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: PerpsDepositService.targetAsset,
            amount: "2.5",
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender
        )
    }

    private func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    private func makeService(
        api: FundingStubAPI,
        delivery: StubDepositDelivery,
        checks: [any OperationCheck] = []
    ) -> PerpsDepositService {
        PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            gate: OperationGate { checks },
            keyRegistration: { KeyRegistrationFixture.registration },
            securityConfig: { KeyRegistrationFixture.security },
            now: { [clock] in clock.now },
            makeOperationId: { "op-1" }
        )
    }
}

/// Finds a warning in whatever it reads, so a gate that asks always does, and keeps what it read.
struct WarningCheck: OperationCheck {
    /// The account a signable is read from, its address lowercased, and the intent it is held to.
    struct Read: Equatable {
        let address: String
        let assetId: String
        let intent: OperationIntent
    }

    actor Reads {
        private(set) var all = [Read]()

        func append(_ read: Read) {
            all.append(read)
        }
    }

    let reads = Reads()

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        await reads.append(Read(address: signable.account.addressDisplay.lowercased(), assetId: signable.account.asset.id, intent: signable.intent))
        return [OperationFinding(id: signable.operation.id, kind: "StubWarning", severity: .warning, title: "Finding")]
    }
}

/// Cannot read what it is given.
struct FailingCheck: OperationCheck {
    struct Failure: Error {}

    func findings(of _: SignableOperation) async throws -> [OperationFinding] {
        throw Failure()
    }
}

/// The user a confirm attempt asks: answers every review alike, once `onAsk` has run.
actor ConsentingUser {
    private(set) var asked = [OperationReview]()
    private let answer: Bool
    private let onAsk: @Sendable () async -> Void

    init(answering answer: Bool, onAsk: @escaping @Sendable () async -> Void = {}) {
        self.answer = answer
        self.onAsk = onAsk
    }

    /// A confirm attempt that asks this user; a review it accepted, it does not ask about again.
    nonisolated func attempt() -> OperationConsent {
        OperationConsent { await self.ask($0) }
    }

    private func ask(_ review: OperationReview) async -> Bool {
        asked.append(review)
        await onAsk()
        return answer
    }
}
