@testable import App
import KeeperCore
import MoonPay
import TKCore
import TKTestSupport
import XCTest

@MainActor
final class BuyCryptoAnalyticsTests: XCTestCase {
    // MARK: - Events

    func test_events_areBuyingWithFiatOnBuyCrypto() throws {
        let (analytics, sent) = makeAnalytics()

        analytics.started()
        analytics.continued(Self.purchase)
        analytics.toProvider(Self.purchase, txId: "tx")

        let started = try XCTUnwrap(sent.events.first as? DepositStarted)
        XCTAssertEqual(started.walletMode, .multi)
        XCTAssertEqual(started.depositScreen, .buyCrypto)
        XCTAssertEqual(started.availableOptions, ["buy_with_fiat"])
        let continued = try XCTUnwrap(sent.events[1] as? DepositClickRampInsertAmountContinue)
        XCTAssertEqual(continued.addFundsOption, .buyWithFiat)
        XCTAssertEqual(continued.depositScreen, .buyCrypto)
        XCTAssertEqual(continued.providerName, "MoonPay")
        let provider = try XCTUnwrap(sent.events[2] as? DepositContinueToRampProvider)
        XCTAssertEqual(provider.txId, "tx")
        XCTAssertEqual(provider.paymentMethod, "card")
        XCTAssertEqual(sent.utms, Array(repeating: Self.utm, count: 3))
    }

    func test_events_carryTheProviderMode() {
        let (analytics, sent) = makeAnalytics()
        let widget = BuyCryptoPurchase(
            assetId: "ton/mainnet/coin",
            fiat: "USD",
            paymentMethod: "card",
            provider: "MoonPay",
            mode: .merchant
        )

        analytics.amountShown(widget)
        analytics.continued(widget)
        analytics.toProvider(widget, txId: "tx_widget")
        analytics.continued(Self.purchase)
        analytics.toProvider(Self.purchase, txId: "tx")
        analytics.result(Self.purchase, txId: "tx", outcome: .success, failureReason: nil)

        XCTAssertEqual((sent.events[0] as? DepositViewRampInsertAmount)?.providerMode, .merchant)
        XCTAssertEqual((sent.events[1] as? DepositClickRampInsertAmountContinue)?.providerMode, .merchant)
        XCTAssertEqual((sent.events[2] as? DepositContinueToRampProvider)?.providerMode, .merchant)
        XCTAssertEqual((sent.events[3] as? DepositClickRampInsertAmountContinue)?.providerMode, .headless)
        XCTAssertEqual((sent.events[4] as? DepositContinueToRampProvider)?.providerMode, .headless)
        XCTAssertEqual((sent.events[5] as? DepositRampResult)?.providerMode, .headless)
    }

    func test_withMode_keepsThePurchase() {
        let merchant = Self.purchase.with(mode: .merchant)

        XCTAssertEqual(merchant.mode, .merchant)
        XCTAssertEqual(merchant.with(mode: .headless), Self.purchase)
    }

    func test_amountShown_isSentOncePerOpening() {
        let (analytics, sent) = makeAnalytics()

        analytics.amountShown(Self.purchase)
        analytics.amountShown(Self.purchase)

        XCTAssertEqual(sent.events.filter { $0 is DepositViewRampInsertAmount }.count, 1)
    }

    func test_receive_isReceiveTokensOnBuyCrypto() throws {
        let (analytics, sent) = makeAnalytics()

        analytics.receiveShown(token: .ton(.ton))

        let event = try XCTUnwrap(sent.events.first as? DepositViewReceiveTokens)
        XCTAssertEqual(event.addFundsOption, .receiveTokens)
        XCTAssertEqual(event.depositScreen, .buyCrypto)
    }

    func test_result_carriesAFailureReasonOnlyWhenFailed() throws {
        let (analytics, sent) = makeAnalytics()

        analytics.result(Self.purchase, txId: "tx", outcome: .failed, failureReason: nil)
        analytics.result(Self.purchase, txId: "tx", outcome: .pending, failureReason: .declined)

        let failed = try XCTUnwrap(sent.events.first as? DepositRampResult)
        XCTAssertEqual(failed.failureReason, .unknown)
        let pending = try XCTUnwrap(sent.events.last as? DepositRampResult)
        XCTAssertNil(pending.failureReason)
    }

    // MARK: - Payment outcome

    func test_completed_isSuccess_reportedOnce() async {
        let (viewModel, continuation, outcomes) = makeStatus()

        continuation.yield(.started(Self.transaction))
        continuation.yield(.completed(Self.transaction))
        await outcomes.waitForFirst()
        viewModel.close()

        XCTAssertEqual(outcomes.values.map(\.outcome), [.success])
    }

    func test_bankDecline_isFailedDeclined() async {
        let (viewModel, continuation, outcomes) = makeStatus()

        continuation.yield(.started(Self.transaction))
        continuation.yield(.failed(.payment(code: "payment_authorization_declined", reason: nil)))
        await outcomes.waitForFirst()
        withExtendedLifetime(viewModel) {}

        XCTAssertEqual(outcomes.values.first?.outcome, .failed)
        XCTAssertEqual(outcomes.values.first?.reason, .declined)
    }

    func test_closedChallenge_isCancelled() async {
        let (viewModel, continuation, outcomes) = makeStatus()

        continuation.yield(.started(Self.transaction))
        continuation.yield(.failed(.challengeCancelled))
        await outcomes.waitForFirst()
        withExtendedLifetime(viewModel) {}

        XCTAssertEqual(outcomes.values.first?.outcome, .cancelled)
    }

    func test_closedWhileMoonPayProcesses_isPending() async {
        let (viewModel, continuation, outcomes) = makeStatus()

        continuation.yield(.pending(Self.transaction))
        await waitForPhaseChange(viewModel)
        viewModel.close()

        XCTAssertEqual(outcomes.values.map(\.outcome), [.pending])
    }

    func test_closedBeforeMoonPaysWindow_isCancelled_once() {
        let (viewModel, _, outcomes) = makeStatus()

        viewModel.close()
        viewModel.sheetDidClose()

        XCTAssertEqual(outcomes.values.map(\.outcome), [.cancelled])
    }

    func test_closedOnceThePaymentReachedMoonPay_beforeTheStart_isUnknown() {
        let (viewModel, _, outcomes) = makeStatus()

        viewModel.paymentDidOpen()
        viewModel.close()

        XCTAssertEqual(outcomes.values.map(\.outcome), [.unknown])
    }

    func test_closedOnceMoonPayNamedTheTransaction_beforeProcessing_isUnknown() async {
        let (viewModel, continuation, outcomes) = makeStatus()

        continuation.yield(.started(Self.transaction))
        await waitForPhaseChange(viewModel)
        viewModel.close()

        XCTAssertEqual(outcomes.values.map(\.outcome), [.unknown])
    }

    func test_failureReasons_followMoonPaysCodes() {
        typealias Reason = DepositRampResult.FailureReason
        XCTAssertEqual(Reason(.payment(code: "daily_purchase_limit_exceeded", reason: nil)), .limitReached)
        XCTAssertEqual(Reason(.payment(code: "timeout_3d_secure", reason: nil)), .notConfirmed)
        XCTAssertEqual(Reason(.payment(code: "cancelled", reason: nil)), .transactionCancelled)
        XCTAssertEqual(Reason(.payment(code: "rejected_kyc", reason: nil)), .verificationUnavailable)
        XCTAssertEqual(Reason(.payment(code: "serviceUnavailable", reason: nil)), .unavailable)
        XCTAssertEqual(Reason(.paymentFrameError(code: "quoteExpired", reason: nil)), .quoteRejected)
        XCTAssertEqual(Reason(.paymentFrameError(code: "invalid_amount", reason: nil)), .quoteRejected)
        XCTAssertEqual(Reason(.paymentFrameError(code: "customer_status_pending", reason: nil)), .verificationPending)
        XCTAssertEqual(Reason(.verificationFailed(.unavailable)), .verificationUnavailable)
        XCTAssertEqual(Reason(.quoteNotExecutable), .quoteRejected)
        XCTAssertEqual(Reason(.payment(code: "something_new", reason: nil)), .unknown)
    }

    // MARK: - Helpers

    private final class Sent {
        var events: [Encodable] = []
        var utms: [UtmParameters] = []
    }

    @MainActor
    private final class Outcomes {
        private(set) var values: [(outcome: DepositRampResult.Outcome, reason: DepositRampResult.FailureReason?)] = []
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func append(_ outcome: DepositRampResult.Outcome, _ reason: DepositRampResult.FailureReason?) {
            values.append((outcome, reason))
            waiters.forEach { $0.resume() }
            waiters = []
        }

        func waitForFirst() async {
            guard values.isEmpty else { return }
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    private func makeAnalytics() -> (BuyCryptoAnalytics, Sent) {
        let sent = Sent()
        let analytics = BuyCryptoAnalytics(source: .jettonScreen, utm: Self.utm) { event, utm in
            sent.events.append(event)
            sent.utms.append(utm)
        }
        return (analytics, sent)
    }

    private func makeStatus() -> (
        MoonPayPaymentStatusViewModel,
        AsyncStream<MoonPayPaymentUpdate>.Continuation,
        Outcomes
    ) {
        let (updates, continuation) = AsyncStream<MoonPayPaymentUpdate>.makeStream()
        let viewModel = MoonPayPaymentStatusViewModel(
            quote: Self.quote,
            paymentTitle: "Card",
            titleForMethod: { _ in nil },
            updates: { updates }
        )
        let outcomes = Outcomes()
        viewModel.onOutcome = { outcomes.append($0, $1) }
        viewModel.start()
        return (viewModel, continuation, outcomes)
    }

    private func waitForPhaseChange(_ viewModel: MoonPayPaymentStatusViewModel) async {
        await waitUntil(viewModel) { viewModel.screenState.steps.first?.status == .done }
    }

    private static let utm = UtmParameters(link: "https://app.tonkeeper.com/buy?utm_source=push")

    private static let purchase = BuyCryptoPurchase(
        assetId: "ton/mainnet/coin",
        fiat: "USD",
        paymentMethod: "card",
        provider: "MoonPay",
        mode: .headless
    )

    private static let transaction = MoonPayTransaction(id: "tx_1", status: "pending")

    private static let quote: MoonPayBuyQuote = {
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"19.9","asset":{"code":"USDT"}},
            "paymentMethod":{"type":"card"},
            "executable":true,
            "signature":"sig"
        }
        """#
        return try! JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
    }()
}
