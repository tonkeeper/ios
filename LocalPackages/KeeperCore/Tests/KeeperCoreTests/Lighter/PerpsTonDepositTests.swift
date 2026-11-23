import BigInt
import Foundation
@testable import KeeperCore
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsTonDepositTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsTonDepositTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testARealQuoteIsReadIntoTheMessageItCarries() async throws {
        let quote = try await read([.ton("p_ton", value: "1398210269")])

        XCTAssertEqual(quote.relayPaymentUnits, 1_398_210_269)
        XCTAssertEqual(quote.sourceAmountUnits, TonQuote.budget)
    }

    func testTheDepositoryIsMatchedInEveryAddressForm() async throws {
        let nonBounceable = try TonSwift.Address.parse(TonDepositFixture.depository).toString(bounceable: false)
        for form in [TonDepositFixture.depository, TonDepositFixture.depositoryBounceable, nonBounceable] {
            let quote = try await read([.ton("p_ton", to: form, value: TonQuote.budget)])

            XCTAssertEqual(quote.relayPaymentUnits, 1_400_000_000, form)
        }
    }

    func testAMessageOfTheWholeBudgetOrOfNoLessThanNinetyNinePercentIsSigned() async throws {
        for value in ["1400000000", "1386000000"] {
            let quote = try await read([.ton("p_ton", value: value)])

            XCTAssertEqual(quote.relayPaymentUnits.map(String.init), value)
        }
    }

    func testOnlySendModesThatSpendTheMessageAloneAreSigned() async throws {
        for mode in [nil, 0, 1, 2, 3] as [Int?] {
            let quote = try await read([.ton("p_ton", value: TonQuote.budget, mode: mode)])

            XCTAssertNotNil(quote.relayPaymentUnits, "mode \(String(describing: mode))")
        }
        for mode in [128, 130, 64, 32] {
            await assertRefused([.ton("p_ton", value: TonQuote.budget, mode: mode)], .unboundedSendMode(payloadId: "p_ton", mode: mode))
        }
    }

    func testAnOrderIdInCapitalsOrInABocWithoutItsChecksumIsStillAnOrderId() async throws {
        for body in [TonDepositFixture.upperCaseOrderIdComment, TonDepositFixture.orderIdCommentWithoutChecksum] {
            let quote = try await read([.ton("p_ton", value: TonQuote.budget, body: body)])

            XCTAssertNotNil(quote.relayPaymentUnits, body)
        }
    }

    func testAMessageAnywhereButRelaysDepositoryIsRefused() async {
        let neighbour = String(TonDepositFixture.depository.dropLast()) + "5"
        for to in [TonQuote.elsewhere, neighbour] {
            await assertRefused([.ton("p_ton", to: to, value: TonQuote.budget)], .unexpectedTonPayment("destination"))
        }
    }

    func testAMessageBesideTheDepositIsRefused() async {
        await assertRefused(
            [.ton("p_ton", value: "1000000000"), .ton("p_extra", to: TonQuote.elsewhere, value: "390000000")],
            .unexpectedTonPayment("payloads")
        )
    }

    func testAMessageShortOfTheBudgetByMoreThanOnePercentIsRefused() async {
        for value in ["1385999999", "0"] {
            await assertRefused([.ton("p_ton", value: value)], .unexpectedTonPayment("value"))
        }
        await assertRefused([.ton("p_ton", value: "1400000001")], .overspend(spent: "1400000001", budget: TonQuote.budget))
    }

    func testOnlyAnOrderIdAsATextCommentIsSigned() async {
        let bodies: [(String, String?)] = [
            ("no body", nil),
            ("a jetton transfer", TonDepositFixture.jettonTransferBody),
            ("bits that are not whole bytes", TonDepositFixture.unalignedBody),
            ("a comment that is not an order id", TonDepositFixture.helloComment),
            ("an order id cut short", TonDepositFixture.shortOrderIdComment),
            ("an order id continued in a second cell", TonDepositFixture.orderIdCommentWithTail),
            ("a ref to a cell the BOC does not hold", TonDepositFixture.orderIdCommentWithDanglingRef),
            ("no base64", "not a boc"),
            ("base64 that is no BOC", Data("0x\(String(repeating: "ab", count: 32))".utf8).base64EncodedString()),
        ]
        for (name, body) in bodies {
            await assertRefused([.ton("p_ton", value: TonQuote.budget, body: body)], .unexpectedTonPayment("body"), name)
        }
    }

    func testACommentOutsideTheBodyIsRefused() async {
        let commented = Components.Schemas.QuotePayload.payload("p_ton", chain: "ton/mainnet", meta: [
            "to": TonDepositFixture.depositoryBounceable,
            "value": TonQuote.budget,
            "comment": "0x" + String(repeating: "ab", count: 32),
        ])

        await assertRefused([commented], .malformedPayload(payloadId: "p_ton"))
    }

    func testWithoutRelaysTonDepositoryInTheSignedBlockNothingIsSignedFromTon() async throws {
        var withoutTon = KeyRegistrationFixture.security
        withoutTon.relayTonDepositories = []
        for security in [nil, withoutTon] {
            await assertRefused([.ton("p_ton", value: TonQuote.budget)], .unexpectedTonPayment("relay depository"), security: security)
        }

        let fromBsc = try await makeService(api: FundingStubAPI(quoteDeposit: .success(KeyRegistrationFixture.bscRelayQuote())), security: withoutTon).quote(
            sourceAsset: KeyRegistrationFixture.bscAsset.assetId,
            sourceAmountUnits: KeyRegistrationFixture.bscAmountUnits,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender
        )
        XCTAssertEqual(fromBsc.relayPaymentUnits.map(String.init), KeyRegistrationFixture.bscAmountUnits)
    }

    func testTheReviewShowsWhatTheMessageCarriesWhileTheDepositKeepsTheAmountEntered() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(TonQuote.quote([.ton("p_ton", value: "1398210269")]))
        )
        let service = makeService(api: api, delivery: delivery)

        let review = try await review(service, registeringKey: false)
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertEqual(review.sourceAmount, "1.4")
        XCTAssertEqual(review.sentAmount, "1.398210269")
        XCTAssertEqual(review.provider, "Relay")
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_ton"])
        let stored = try await journal().allFunding()
        XCTAssertEqual(stored.map(\.deposit?.sourceAmountUnits), [TonQuote.budget])
    }

    func testADepositStraightToTheGatewayNamesNoProviderAndNoSentAmount() async throws {
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())))

        let review = try await service.review(
            sourceAsset: PerpsDepositService.targetAsset,
            amount: "2.5",
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        XCTAssertNil(review.sentAmount)
        XCTAssertNil(review.provider)
    }

    func testAReviewOfAMessageToAnotherAddressSignsNothing() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(quoteDeposit: .success(TonQuote.quote([.ton("p_ton", to: TonQuote.elsewhere, value: TonQuote.budget)])))

        do {
            _ = try await review(makeService(api: api, delivery: delivery), registeringKey: false)
            XCTFail("a message to another address must not be shown")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedTonPayment("destination"))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
        XCTAssertEqual(delivery.openedSessionCount, 0)
    }

    func testAFirstDepositChecksThePaymentItShowsAndThePaymentQuotedAfterThePasscode() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.firstDepositAPI(
            payment: TonQuote.quote([.ton("p_ton", value: "1398210269")], uninitialized: true),
            signed: TonQuote.quote([.ton("p_ton", value: "1399000000")])
        )
        let service = makeService(api: api, delivery: delivery)

        let review = try await review(service)
        guard case .registering = review.payment else { return XCTFail("\(review.payment)") }
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertEqual(review.sentAmount, "1.398210269")
        XCTAssertEqual(review.provider, "Relay")
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute", "send:p_ton"])
        let stored = try await journal().allFunding()
        XCTAssertEqual(stored.map(\.deposit?.sourceAmountUnits), [TonQuote.budget])
    }

    func testAFirstDepositWhosePaymentQuoteGoesElsewhereIsNotShown() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.firstDepositAPI(
            payment: TonQuote.quote([.ton("p_ton", to: TonQuote.elsewhere, value: TonQuote.budget)], uninitialized: true),
            signed: TonQuote.quote([.ton("p_ton", value: TonQuote.budget)])
        )

        do {
            _ = try await review(makeService(api: api, delivery: delivery))
            XCTFail("a first deposit paying another address must not be shown")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedTonPayment("destination"))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testAFirstDepositWhoseQuoteAfterThePasscodeChangesTheMessageIsNeverSent() async throws {
        let replaced: [(String, Components.Schemas.QuotePayload, PerpsDepositQuoteError)] = [
            ("another address", .ton("p_ton", to: TonQuote.elsewhere, value: TonQuote.budget), .unexpectedTonPayment("destination")),
            ("a jetton transfer", .ton("p_ton", value: TonQuote.budget, body: TonDepositFixture.jettonTransferBody), .unexpectedTonPayment("body")),
            ("the whole balance", .ton("p_ton", value: TonQuote.budget, mode: 128), .unboundedSendMode(payloadId: "p_ton", mode: 128)),
        ]
        for (name, payload, expected) in replaced {
            let delivery = StubDepositDelivery()
            let api = Self.firstDepositAPI(
                payment: TonQuote.quote([.ton("p_ton", value: TonQuote.budget)], uninitialized: true),
                signed: TonQuote.quote([payload])
            )
            let service = makeService(api: api, delivery: delivery)
            let review = try await review(service)

            do {
                _ = try await service.pay(review: review, passcode: "0000", consent: .refuse)
                XCTFail("\(name) must not be sent")
            } catch {
                XCTAssertEqual(error as? PerpsDepositQuoteError, expected, name)
            }
            let events = await delivery.session.events
            XCTAssertEqual(events, ["sign:p_auth,p_execute"], name)
            let stored = try await journal().allFunding()
            XCTAssertTrue(stored.isEmpty, name)
        }
    }

    func testAJournaledTonPaymentShowsWhatItCarriesAndIsSentOnResume() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending))), delivery: delivery)
        _ = try await journal().saveFundingIfAbsent(journaledPayment(.ton("p_ton", value: "1398210269")))

        let pending = try await service.pendingReview()
        let review = try XCTUnwrap(pending)
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertEqual(review.sentAmount, "1.398210269")
        XCTAssertEqual(review.provider, "Relay")
        XCTAssertEqual(outcome, .registered(operationId: "op-journaled"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_ton"])
    }

    func testAJournaledTonPaymentToAnotherAddressIsRefusedBeforeItIsOffered() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(), delivery: delivery)
        _ = try await journal().saveFundingIfAbsent(journaledPayment(.ton("p_ton", to: TonQuote.elsewhere, value: TonQuote.budget)))

        do {
            _ = try await service.pendingReview()
            XCTFail("a journaled message to another address must not be offered")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedTonPayment("destination"))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testAJournaledTonPaymentIsCheckedAgainstTheBlockInForceWhenItIsResumed() async throws {
        let delivery = StubDepositDelivery()
        let served = ServedSecurityConfig(KeyRegistrationFixture.security)
        let service = makeService(api: FundingStubAPI(), delivery: delivery, served: served)
        _ = try await journal().saveFundingIfAbsent(journaledPayment(.ton("p_ton", value: TonQuote.budget)))
        let pending = try await service.pendingReview()
        let review = try XCTUnwrap(pending)
        var withoutTon = KeyRegistrationFixture.security
        withoutTon.relayTonDepositories = []
        served.serve(withoutTon)

        do {
            _ = try await service.pay(review: review, passcode: "0000", consent: .refuse)
            XCTFail("a journaled message must not be signed without Relay's depository")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedTonPayment("relay depository"))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    func testATonPaymentAlreadySignedIsResumedWithoutTheRelayRow() async throws {
        var signed = ChainKitSignedTransaction(payloadId: "p_ton", nonce: "0", data: "signed:p_ton", hash: StubDepositSigningSession.hash(of: "p_ton"), acknowledged: false)
        signed.broadcastAttempted = true
        _ = try await journal().saveFundingIfAbsent(journaledPayment(.ton("p_ton", value: "1398210269"), steps: [signed]))

        let pending = try await makeService(api: FundingStubAPI(), security: nil).pendingReview()
        let review = try XCTUnwrap(pending)

        XCTAssertNil(review.sentAmount)
        XCTAssertNil(review.provider)
    }

    func testAJettonPaymentThroughOmnistonIsSignedAsTheBackendBuiltIt() async throws {
        let quote = try await readJetton(OmnistonQuote.quote())

        XCTAssertEqual(quote.provider, .omniston)
        XCTAssertNil(quote.relayPaymentUnits)
    }

    func testAJettonIsPaidOnlyThroughOmnistonInOneMessage() async {
        var relayed = OmnistonQuote.quote()
        relayed.provider = "relay"
        await assertJettonRefused(relayed, .unexpectedTonPayment("provider"))

        let twoMessages = OmnistonQuote.quote([OmnistonQuote.main, .ton("p_more", value: "1000000", bounce: true, mode: 3)])
        await assertJettonRefused(twoMessages, .unexpectedPayloads(["p_main", "p_more"]))
    }

    func testOmnistonIsRefusedForTonItselfAndOnAnotherChain() async throws {
        var fromTon = TonQuote.quote([.ton("p_ton", value: TonQuote.budget)])
        fromTon.provider = "omniston"
        do {
            _ = try await makeService(api: FundingStubAPI(quoteDeposit: .success(fromTon))).quote(
                sourceAsset: PaymentFixture.tonAsset.assetId,
                sourceAmountUnits: TonQuote.budget,
                senderAddress: PaymentFixture.tonSender,
                beneficiary: PaymentFixture.sender
            )
            XCTFail("TON itself is not paid through Omniston")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedTonPayment("provider"))
        }

        var fromBsc = KeyRegistrationFixture.bscRelayQuote()
        fromBsc.provider = "omniston"
        do {
            _ = try await makeService(api: FundingStubAPI(quoteDeposit: .success(fromBsc))).quote(
                sourceAsset: KeyRegistrationFixture.bscAsset.assetId,
                sourceAmountUnits: KeyRegistrationFixture.bscAmountUnits,
                senderAddress: PaymentFixture.sender,
                beneficiary: PaymentFixture.sender
            )
            XCTFail("Omniston pays only from TON")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedProvider("omniston"))
        }
    }

    func testTheReviewOfAJettonPaymentCountsTheTonItCarriesAndNamesNoProvider() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDeposit: .success(OmnistonQuote.quote())
        )
        let service = makeService(api: api, delivery: delivery)

        let review = try await service.review(
            sourceAsset: OmnistonQuote.usdt,
            amount: "25",
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertEqual(review.carriedNativeAmount, "0.4")
        XCTAssertNil(review.sentAmount)
        XCTAssertNil(review.provider)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_main"])
    }

    func testAJournaledJettonPaymentIsResumedWithoutTheRelayRow() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending))), delivery: delivery)
        _ = try await journal().saveFundingIfAbsent(journaledPayment(OmnistonQuote.quote(), sourceAsset: OmnistonQuote.usdt))

        let pending = try await service.pendingReview()
        let review = try XCTUnwrap(pending)
        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertNil(review.sentAmount)
        XCTAssertNil(review.provider)
        XCTAssertNil(review.carriedNativeAmount)
        XCTAssertEqual(outcome, .registered(operationId: "op-journaled"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_main"])
    }

    private func readJetton(_ quote: Components.Schemas.DepositQuote) async throws -> PerpsDepositQuote {
        try await makeService(api: FundingStubAPI(quoteDeposit: .success(quote))).quote(
            sourceAsset: OmnistonQuote.usdt.assetId,
            sourceAmountUnits: OmnistonQuote.budget,
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender
        )
    }

    private func assertJettonRefused(
        _ quote: Components.Schemas.DepositQuote,
        _ expected: PerpsDepositQuoteError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await readJetton(quote)
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, expected, file: file, line: line)
        }
    }

    private func read(
        _ payloads: [Components.Schemas.QuotePayload],
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security
    ) async throws -> PerpsDepositQuote {
        try await makeService(api: FundingStubAPI(quoteDeposit: .success(TonQuote.quote(payloads))), security: security).quote(
            sourceAsset: PaymentFixture.tonAsset.assetId,
            sourceAmountUnits: TonQuote.budget,
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender
        )
    }

    private func assertRefused(
        _ payloads: [Components.Schemas.QuotePayload],
        _ expected: PerpsDepositQuoteError,
        _ message: String = "",
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await read(payloads, security: security)
            XCTFail("expected \(expected) \(message)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, expected, message, file: file, line: line)
        }
    }

    private func review(_ service: PerpsDepositService, registeringKey: Bool = true) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: PaymentFixture.tonAsset,
            amount: "1.4",
            senderAddress: PaymentFixture.tonSender,
            beneficiary: PaymentFixture.sender,
            registeringKey: registeringKey
        )
    }

    private static func firstDepositAPI(
        payment: Components.Schemas.DepositQuote,
        signed: Components.Schemas.DepositQuote
    ) -> FundingStubAPI {
        let preview = KeyRegistrationFixture.previewQuote(base: payment)
        return FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDepositHandler: { request in
                guard request.change_pub_key != nil else { return payment }
                return request.operation == nil ? preview : signed
            }
        )
    }

    private func journaledPayment(
        _ payload: Components.Schemas.QuotePayload,
        steps: [ChainKitSignedTransaction] = []
    ) throws -> PerpsPendingFundingOperation {
        try journaledPayment(TonQuote.quote([payload]), sourceAsset: PaymentFixture.tonAsset, steps: steps)
    }

    private func journaledPayment(
        _ quote: Components.Schemas.DepositQuote,
        sourceAsset: PerpsFundingAsset,
        steps: [ChainKitSignedTransaction] = []
    ) throws -> PerpsPendingFundingOperation {
        var deposit = PerpsPendingDeposit(
            stage: .sourcePending,
            route: .crosschainSwap,
            beneficiary: PaymentFixture.sender,
            sourceAsset: sourceAsset,
            sourceAmountUnits: quote.input.amount,
            targetAsset: PerpsDepositService.targetAsset,
            minimumTargetAmountUnits: quote.output.min_amount,
            executionId: "exec-1",
            quoteId: quote.quote_id
        )
        deposit.transmission = try PerpsDepositTransmission(
            operation: PerpsDepositOperation(quote.operation),
            sender: PaymentFixture.tonSender,
            expiresAt: quote.expires_at,
            steps: steps
        )
        return .init(operationId: "op-journaled", walletId: "multichain-wallet", walletIdentity: "wallet", environment: "mainnet", details: .deposit(deposit))
    }

    private func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    private func makeService(
        api: FundingStubAPI,
        delivery: StubDepositDelivery = StubDepositDelivery(),
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        served: ServedSecurityConfig? = nil
    ) -> PerpsDepositService {
        let served = served ?? ServedSecurityConfig(security)
        return PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            gate: OperationGate { [] },
            keyRegistration: { KeyRegistrationFixture.registration },
            securityConfig: { served.config },
            now: { KeyRegistrationFixture.now },
            makeOperationId: { "op-1" }
        )
    }
}

private enum TonQuote {
    static let budget = "1400000000"
    static let elsewhere = TonSwift.Address.mock(workchain: 0, seed: "elsewhere").toString(bounceable: false)

    static func quote(_ payloads: [Components.Schemas.QuotePayload], uninitialized: Bool? = nil) -> Components.Schemas.DepositQuote {
        var quote = PaymentFixture.crosschainQuote(
            asset: PaymentFixture.tonAsset.assetId,
            amount: budget,
            sender: PaymentFixture.tonSender,
            payloads: payloads
        )
        quote.account_uninitialized = uninitialized
        return quote
    }
}

enum OmnistonQuote {
    static let usdt = PerpsFundingAsset(
        assetId: "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
        symbol: "USD₮",
        decimals: 6
    )
    static let budget = "25000000"
    static let jettonWallet = TonSwift.Address.mock(workchain: 0, seed: "jetton wallet").toString(bounceable: true)
    static let main = Components.Schemas.QuotePayload.ton("p_main", to: jettonWallet, value: "400000000", bounce: true, mode: 3)

    static func quote(_ payloads: [Components.Schemas.QuotePayload] = [main]) -> Components.Schemas.DepositQuote {
        var quote = PaymentFixture.crosschainQuote(asset: usdt.assetId, amount: budget, sender: PaymentFixture.tonSender, payloads: payloads)
        quote.provider = "omniston"
        return quote
    }
}
