import ChainKit
import Foundation
@testable import KeeperCore
import OperationReviewModels
import TKFeatureFlags
import TKLocalize
import TKPerpsAPI
import XCTest

/// A deposit through a gate composed as the Perps assembly composes it: what chain-kit flags in
/// what it signs is asked about before anything is written, and nothing changes while the boot
/// configuration turns validation off or with nothing found.
final class PerpsDepositValidationTests: XCTestCase {
    private var directoryURL: URL!
    private let clock = PaymentClock(Date(timeIntervalSince1970: 1_700_000_000))
    private lazy var client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
        isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil
    )))

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsDepositValidationTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    /// A payment that sends ten times what was typed to an address of the quote's choosing is not
    /// Relay's deposit: the client refuses it at the review, before anything is built, asked or written.
    func testAPaymentThatSendsMoreThanTypedElsewhereIsRefusedBeforeAnythingIsAskedOrWritten() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(Self.drainingQuote))
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, flags: ReviewFlags())

        do {
            _ = try await review(service)
            XCTFail("a draining payment must not be shown")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedChainPayment("relay payment"))
        }
        XCTAssertEqual(delivery.accountRequests, [], "nothing built to review")
        let journaled = try await journal().allFunding()
        XCTAssertEqual(journaled.map(\.operationId), [])
        let posted = await api.openDepositRequests
        XCTAssertEqual(posted.count, 0)
        let events = await delivery.session.events
        XCTAssertEqual(events, [])
    }

    /// An aggregator's approval and call read as info at most: the swipe is not stopped.
    func testAPaymentChainKitFindsNothingInIsNotAskedAbout() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.approvedRelayQuote()))
        let service = makeService(api: api, delivery: StubDepositDelivery(), flags: ReviewFlags())
        let review = try await review(service)
        let user = ConsentingUser(answering: false)

        let outcome = try await service.pay(review: review, passcode: "0000", consent: user.attempt())

        XCTAssertEqual(review.review?.requiresConsent, false)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked, [])
    }

    func testWithTheFlagOffAPaymentIsPaidAsBeforeWithNothingBuilt() async throws {
        let api = FundingStubAPI(openDeposit: .success(.init(deposit_id: "deposit", status: .pending)), quoteDeposit: .success(PaymentFixture.approvedRelayQuote()))
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, flags: ReviewFlags(), validates: false)
        let review = try await review(service)

        let outcome = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        XCTAssertNil(review.review)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        XCTAssertEqual(delivery.accountRequests, [], "nothing built to review")
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_approve,p_relay"])
    }

    /// Max prices a deposit over and over and confirms none of those prices: nothing is built for
    /// chain-kit to check.
    func testAReviewThatIsOnlyPricedChecksNothing() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.approvedRelayQuote())), delivery: delivery, flags: ReviewFlags())

        let priced = try await review(service, previewing: false)

        XCTAssertNil(priced.review)
        XCTAssertEqual(priced.networkFee, "0.000042")
        XCTAssertEqual(delivery.accountRequests, [], "nothing built to check")
    }

    /// What a first deposit signs reads clean to chain-kit: the documents that register its trading
    /// key, from another chain with the delegation of the Ethereum account they register, and the
    /// payment quoted once they are signed.
    func testAFirstDepositFromAnotherChainIsNotAskedAbout() async throws {
        let api = Self.registering(plain: KeyRegistrationFixture.bscRelayQuote(), preview: KeyRegistrationFixture.previewQuote())

        let events = try await payFirstDeposit(of: KeyRegistrationFixture.bscAsset, api: api)

        XCTAssertEqual(events, ["sign:p_auth,p_execute", "send:p_approve,p_relay"])
    }

    /// From Ethereum the documents are the call alone, and the payment quoted once they are signed
    /// carries the delegation.
    func testAFirstDepositFromEthereumIsNotAskedAbout() async throws {
        let delegated = PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [
            .evm(
                "p_relay",
                to: PaymentFixture.relayDepository,
                data: RelayFixture.depositErc20(token: PaymentFixture.usdt, amountUnits: "25000000"),
                authorization: HermesBatchFixture.authorization()
            ),
        ])
        let api = Self.registering(plain: PaymentFixture.approvedRelayQuote(), preview: KeyRegistrationFixture.ethereumPreviewQuote(), signed: delegated)

        let events = try await payFirstDeposit(of: PaymentFixture.usdtFundingAsset, api: api)

        XCTAssertEqual(events, ["sign:p_execute", "send:p_relay"])
    }

    /// A deposit to the gateway from Ethereum delegates the account in its one transaction: the
    /// authorization and the batch it runs read clean to chain-kit.
    func testAFoldedDepositIsNotAskedAbout() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.foldedQuote())), delivery: delivery, flags: ReviewFlags())
        let review = try await review(service, asset: PerpsDepositService.targetAsset, amount: "2.5")
        let user = ConsentingUser(answering: false)

        let outcome = try await service.pay(review: review, passcode: "0000", consent: user.attempt())

        XCTAssertEqual(review.review?.requiresConsent, false)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_batch"])
    }
}

private extension PerpsDepositValidationTests {
    /// 25 USDT from Ethereum whose one payment sends 250 of them to an address of the quote's choosing.
    static let drainingQuote = PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [
        .evm(
            "p_relay",
            to: PaymentFixture.usdt,
            data: "0xa9059cbb" + String(repeating: "0", count: 24) + String(repeating: "a", count: 40)
                + String(repeating: "0", count: 57) + "ee6b280"
        ),
    ])

    /// Answers a quote asked without the trading key with `plain`, the key's registration asked
    /// unsigned with `preview`, and the registration signed with `signed`, the plain quote by default.
    static func registering(
        plain: Components.Schemas.DepositQuote,
        preview: Components.Schemas.DepositQuote,
        signed: Components.Schemas.DepositQuote? = nil
    ) -> FundingStubAPI {
        FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDepositHandler: { request in
                guard request.change_pub_key != nil else { return plain }
                return request.operation == nil ? preview : signed ?? plain
            }
        )
    }

    /// Pays a first deposit of `asset` for a user who refuses whatever is asked: neither the documents
    /// the swipe shows nor what the final gates read ask, so the deposit is paid. What was signed and
    /// sent, in order.
    func payFirstDeposit(of asset: PerpsFundingAsset, api: FundingStubAPI, line: UInt = #line) async throws -> [String] {
        let delivery = StubDepositDelivery()
        let service = makeService(api: api, delivery: delivery, flags: ReviewFlags())
        let review = try await review(service, asset: asset)
        let user = ConsentingUser(answering: false)

        let outcome = try await service.pay(review: review, passcode: "0000", consent: user.attempt())

        XCTAssertEqual(review.review?.requiresConsent, false, "the documents", line: line)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"), line: line)
        let asked = await user.asked
        XCTAssertEqual(asked, [], line: line)
        return await delivery.session.events
    }

    func review(
        _ service: PerpsDepositService,
        asset: PerpsFundingAsset = PaymentFixture.usdtFundingAsset,
        amount: String = "25",
        previewing: Bool = true
    ) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: asset,
            amount: amount,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender,
            previewing: previewing
        )
    }

    func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    func makeService(
        api: FundingStubAPI,
        delivery: StubDepositDelivery,
        flags: ReviewFlags,
        validates: Bool = true
    ) -> PerpsDepositService {
        PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            gate: OperationGate(configuration: .review(flags, validates: validates), validatingWith: client),
            keyRegistration: { KeyRegistrationFixture.registration },
            securityConfig: { KeyRegistrationFixture.security },
            now: { [clock] in clock.now },
            makeOperationId: { "op-1" }
        )
    }
}
