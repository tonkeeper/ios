@testable import App
import AppUI
import MoonPay
import TKLocalize
import TKTestSupport
import XCTest

@MainActor
final class MoonPayPaymentStatusViewModelTests: XCTestCase {
    func test_stillProcessing_thenCompleted_showsCompleted() async {
        let (viewModel, continuation) = makeViewModel()
        let transaction = MoonPayTransaction(id: "tx_1", status: "pending")

        continuation.yield(.pending(transaction))
        continuation.yield(.stillProcessing(transaction))
        // Only `.stillProcessing` puts this subtitle on the Completed step.
        await waitUntil(viewModel) {
            self.completedStep(viewModel)?.subtitle == TKLocales.Ramp.Moonpay.Status.stillProcessingSubtitle
        }
        XCTAssertEqual(completedStep(viewModel)?.status, .inProgress)

        continuation.yield(.completed(MoonPayTransaction(id: "tx_1", status: "completed")))
        await waitUntil(viewModel) { self.completedStep(viewModel)?.status == .done }

        XCTAssertEqual(viewModel.screenState.steps.map(\.status), [.done, .done, .done])
    }

    func test_stillProcessing_thenFailed_keepsTheStartedStep() async {
        let (viewModel, continuation) = makeViewModel()
        let transaction = MoonPayTransaction(id: "tx_1", status: "pending")

        continuation.yield(.pending(transaction))
        continuation.yield(.stillProcessing(transaction))
        continuation.yield(.failed(.payment(code: "declined", reason: nil)))
        await waitUntil(viewModel) { viewModel.screenState.steps.contains { $0.status == .failed } }

        XCTAssertEqual(viewModel.screenState.steps.first?.status, .done)
    }

    func test_stillProcessing_thenOutcomeUnknown_marksTheCompletedStepUnknown() async {
        let (viewModel, continuation) = makeViewModel()
        let transaction = MoonPayTransaction(id: "tx_1", status: "pending")

        continuation.yield(.pending(transaction))
        continuation.yield(.stillProcessing(transaction))
        continuation.yield(.outcomeUnknown)
        await waitUntil(viewModel) { self.completedStep(viewModel)?.status == .failed }

        XCTAssertEqual(viewModel.screenState.steps.map(\.status), [.done, .done, .failed])
        XCTAssertEqual(completedStep(viewModel)?.title, TKLocales.Ramp.Moonpay.Status.unknownTitle)
        // Nothing confirmed the network cleared it.
        XCTAssertEqual(viewModel.screenState.steps[1].subtitle, TKLocales.Ramp.Moonpay.Status.pendingSubtitle)
    }

    func test_bankDecline_showsPaymentDeclined_withTryAnotherCard() async {
        let (viewModel, continuation) = makeViewModel()
        let transaction = MoonPayTransaction(id: "tx_1", status: "pending")

        continuation.yield(.started(transaction))
        continuation.yield(.failed(.payment(code: "payment_authorization_declined", reason: "Payment")))
        await waitUntil(viewModel) { viewModel.screenState.steps.contains { $0.status == .failed } }

        typealias Status = TKLocales.Ramp.Moonpay.Status
        let failed = viewModel.screenState.steps.first { $0.status == .failed }
        XCTAssertEqual(failed?.title, Status.declinedTitle)
        XCTAssertEqual(failed?.subtitle, Status.declinedSubtitle)
        XCTAssertEqual(viewModel.screenState.actionTitle, Status.tryAnotherCard)
    }

    func test_paymentCodes_mapToFailures() {
        typealias Failure = MoonPayPaymentStatusViewModel.Failure
        let cases: [(String?, Failure)] = [
            ("authorizationDeclined", .declined),
            ("transactionDeclined", .declined),
            ("payment_authorization_declined", .declined),
            ("card_not_supported", .declined),
            ("rejected_card", .declined),
            ("daily_purchase_limit_exceeded", .dailyLimit),
            ("timeout_3d_secure", .notConfirmed),
            ("timeout_card_verification", .notConfirmed),
            ("timeout_bank_transfer", .notConfirmed),
            ("timeout_kyc_verification", .notConfirmed),
            ("serviceUnavailable", .unavailable),
            ("applePayMerchantUnavailable", .unavailable),
            ("error", .unavailable),
            // Android has texts of its own for these, which this screen does not.
            ("rejected_kyc", .generic),
            ("validationError", .generic),
            ("cancelled", .generic),
            ("transactionNotAllowed", .generic),
            ("rejected_other", .generic),
            (nil, .generic),
        ]
        for (code, failure) in cases {
            XCTAssertEqual(Failure(paymentCode: code), failure, code ?? "nil")
            XCTAssertEqual(Failure(.payment(code: code, reason: nil)), failure, code ?? "nil")
        }
        // A frame's error event has codes of its own: they never read as a transaction's.
        XCTAssertEqual(Failure(.paymentFrameError(code: "authorizationDeclined", reason: nil)), .generic)
        XCTAssertEqual(Failure(.paymentFrameError(code: "error", reason: nil)), .generic)
    }

    func test_closedChallenge_afterTheStart_cancels_notFails() async {
        let (viewModel, continuation) = makeViewModel()
        let cancelled = TestSignal()
        var didCancel = false
        viewModel.onCancel = {
            didCancel = true
            cancelled.send()
        }

        continuation.yield(.started(MoonPayTransaction(id: "tx_1", status: "pending")))
        continuation.yield(.failed(.challengeCancelled))
        await waitUntil(cancelled) { didCancel }

        XCTAssertFalse(viewModel.screenState.steps.contains { $0.status == .failed })
    }

    func test_cancelAfterTheStart_otherThanTheChallenge_stillFails() async {
        let (viewModel, continuation) = makeViewModel()

        continuation.yield(.started(MoonPayTransaction(id: "tx_1", status: "pending")))
        continuation.yield(.failed(.paymentCancelled))
        await waitUntil(viewModel) { viewModel.screenState.steps.contains { $0.status == .failed } }
    }

    func test_receivedAmount_usesTheAppsAssetName_notMoonPaysCode() throws {
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"0.006738808","asset":{"code":"ETH_ARBITRUM"}},
            "executable":true,
            "signature":"sig"
        }
        """#
        let quote = try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
        var formatted: [Decimal] = []
        let (viewModel, _) = makeViewModel(quote: quote) { amount in
            formatted.append(amount)
            return "0.00674 ETH"
        }

        typealias Status = TKLocales.Ramp.Moonpay.Status
        let state = viewModel.screenState
        XCTAssertEqual(state.summary.first { $0.id == "receive" }?.value, "0.00674 ETH")
        XCTAssertEqual(completedStep(viewModel)?.subtitle, Status.completedSubtitle("0.00674 ETH"))
        XCTAssertEqual(formatted.first, try XCTUnwrap(Decimal(string: "0.006738808")))
    }

    func test_receivedAmount_withoutAFormatter_showsTheQuote() {
        let (viewModel, _) = makeViewModel()

        XCTAssertEqual(viewModel.screenState.summary.first { $0.id == "receive" }?.value, "19.9 USDT")
    }

    func test_fees_showMoonPayKeeperAndNetwork_andLeaveOutPartner() throws {
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"19.9","asset":{"code":"USDT"}},
            "fees":{
                "network":{"amount":"0.50","asset":{"code":"USD"}},
                "moonpay":{"amount":"3.99","asset":{"code":"USD"}},
                "ecosystem":{"amount":"1.00","asset":{"code":"USD"}},
                "defi":{"amount":"0.25","asset":{"code":"USD"}},
                "partner":{"amount":"1.00","asset":{"code":"USD"}}
            },
            "executable":true,
            "signature":"sig"
        }
        """#
        let quote = try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
        let (viewModel, _) = makeViewModel(quote: quote)

        typealias Status = TKLocales.Ramp.Moonpay.Status
        XCTAssertEqual(
            viewModel.screenState.feeDetails.map(\.title),
            [Status.feeMoonpay, Status.feeEcosystem, Status.feeNetwork, Status.feeOther]
        )
        // DeFi goes to the other fees row, so the rows add up to the total; the deprecated
        // partner fee counts nowhere.
        XCTAssertEqual(viewModel.screenState.feeDetails.last?.value, "$0.25")
        XCTAssertEqual(viewModel.screenState.feesValue, "$5.74")
    }

    func test_fees_rowsAndTotalTakeTheSameFees() throws {
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"19.9","asset":{"code":"USDT"}},
            "fees":{
                "moonpay":{"amount":"3.99","asset":{"code":"usd"}},
                "Partner":{"amount":"1.00","asset":{"code":"USD"}},
                "network":{"amount":"0.40","asset":{"code":"EUR"}}
            },
            "executable":true,
            "signature":"sig"
        }
        """#
        let quote = try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
        let (viewModel, _) = makeViewModel(quote: quote)

        // The key and the currency compare in any case; a fee in another currency has no row and
        // no part in the total.
        XCTAssertEqual(viewModel.screenState.feeDetails.map(\.id), ["moonpay"])
        XCTAssertEqual(viewModel.screenState.feesValue, "$3.99")
    }

    func test_fees_rowsAndTotalPrintTheSameParsedAmounts() throws {
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"19.9","asset":{"code":"USDT"}},
            "fees":{
                "moonpay":{"amount":"n/a","asset":{"code":"USD"}},
                "network":{"amount":"0.40","asset":{"code":"USD"}},
                "defi":{"asset":{"code":"USD"}}
            },
            "executable":true,
            "signature":"sig"
        }
        """#
        let quote = try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
        let (viewModel, _) = makeViewModel(quote: quote)

        // An amount that does not parse has no row; the rest print as the total does.
        XCTAssertEqual(viewModel.screenState.feeDetails.map(\.id), ["network"])
        XCTAssertEqual(viewModel.screenState.feeDetails.map(\.value), ["$0.40"])
        XCTAssertEqual(viewModel.screenState.feesValue, "$0.40")
    }

    func test_fees_keysThatDifferOnlyInCase_areSummed() throws {
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"19.9","asset":{"code":"USDT"}},
            "fees":{
                "network":{"amount":"0.40","asset":{"code":"USD"}},
                "Network":{"amount":"0.10","asset":{"code":"USD"}}
            },
            "executable":true,
            "signature":"sig"
        }
        """#
        let quote = try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
        let (viewModel, _) = makeViewModel(quote: quote)

        XCTAssertEqual(viewModel.screenState.feeDetails.map(\.value), ["$0.50"])
        XCTAssertEqual(viewModel.screenState.feesValue, "$0.50")
    }

    func test_fees_withoutACurrencyCode_haveNoTrailingSpace() throws {
        let json = #"""
        {
            "source":{"amount":"20","asset":{}},
            "destination":{"amount":"19.9","asset":{"code":"USDT"}},
            "fees":{"network":{"amount":"0.40","asset":{}}},
            "executable":true,
            "signature":"sig"
        }
        """#
        let quote = try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
        let (viewModel, _) = makeViewModel(quote: quote)

        XCTAssertEqual(viewModel.screenState.feeDetails.map(\.value), ["0.40"])
        XCTAssertEqual(viewModel.screenState.feesValue, "0.40")
    }

    func test_paidAmounts_carryTheCurrencySymbolAndTheCents() throws {
        typealias ViewModel = MoonPayPaymentStatusViewModel
        XCTAssertEqual(ViewModel.paidText(200, code: "usd"), "$200.00")
        XCTAssertEqual(ViewModel.paidText(200, code: "USD", dropsWholeCents: true), "$200")
        XCTAssertEqual(try ViewModel.paidText(XCTUnwrap(Decimal(string: "13.3")), code: "USD"), "$13.30")
        XCTAssertEqual(try ViewModel.paidText(XCTUnwrap(Decimal(string: "13.305")), code: "USD"), "$13.305")
        XCTAssertEqual(try ViewModel.paidText(XCTUnwrap(Decimal(string: "13.3")), code: "USD", dropsWholeCents: true), "$13.30")
        XCTAssertEqual(ViewModel.paidText(2500, code: "EUR"), "€2\u{00A0}500.00")
        XCTAssertEqual(try ViewModel.paidText(XCTUnwrap(Decimal(string: "0.4")), code: nil), "0.40")
        XCTAssertEqual(ViewModel.paidText(200, code: "ARS", dropsWholeCents: true), "200\u{00A0}ARS$")
        XCTAssertEqual(ViewModel.paidText(200, code: "COP", dropsWholeCents: true), "200\u{00A0}COL$")
    }

    func test_pendingStep_onceDone_readsClearedByTheNetwork() async {
        let (viewModel, continuation) = makeViewModel()
        let transaction = MoonPayTransaction(id: "tx_1", status: "pending")

        continuation.yield(.pending(transaction))
        await waitUntil(viewModel) { viewModel.screenState.steps[1].status == .done }

        XCTAssertEqual(viewModel.screenState.steps[1].subtitle, TKLocales.Ramp.Moonpay.Status.clearedSubtitle)
    }

    private func makeViewModel(
        quote: MoonPayBuyQuote? = nil,
        formatReceived: ((Decimal) -> String)? = nil
    ) -> (MoonPayPaymentStatusViewModel, AsyncStream<MoonPayPaymentUpdate>.Continuation) {
        let (updates, continuation) = AsyncStream<MoonPayPaymentUpdate>.makeStream()
        let viewModel = MoonPayPaymentStatusViewModel(
            quote: quote ?? Self.quote,
            paymentTitle: "Card",
            formatReceived: formatReceived,
            titleForMethod: { _ in nil },
            updates: { updates }
        )
        viewModel.start()
        return (viewModel, continuation)
    }

    private func completedStep(_ viewModel: MoonPayPaymentStatusViewModel) -> MoonPayPaymentStatusViewState.Step? {
        viewModel.screenState.steps.last
    }

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
