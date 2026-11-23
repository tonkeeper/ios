import Combine
import OperationReviewModels
@testable import Perps
import PerpsModels
import TKLocalize
import TKTestSupport
import TKUIKit
import XCTest

/// Announces each change a wait in this file reads: the view model's, a stub's or a callback's.
private let changed = TestSignal()
private let untilCancelled = TestGate()

@MainActor
final class PerpsDepositConfirmViewModelTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()

    func testDepositTitleAvoidsRepeatedTickerButKeepsDistinctNetwork() {
        for (symbol, network, expectedSuffix) in [
            ("BNB", PerpsFundingNetwork.bsc, "BSC" as String?),
            ("TON", .ton, nil),
            ("ETH", .base, PerpsFundingNetwork.base.displayName as String?),
            ("USDT", .bsc, PerpsFundingNetwork.bsc.displayName as String?),
        ] {
            let viewModel = PerpsDepositConfirmViewModel(
                reviewed: Self.reviewed(sourceSymbol: symbol, expiresAt: nil),
                walletName: "", source: .init(assetId: "asset", symbol: symbol, decimals: 6, network: network),
                balance: nil, format: .test, message: { _ in .failed }, passcodeProvider: { nil }, consent: { .refuse }
            )
            XCTAssertEqual(viewModel.titleSuffixText, expectedSuffix)
        }
    }

    func testAKeyRegisteringDepositCompletesWithOneConfirmation() async {
        let now = Date(timeIntervalSince1970: 100)
        let networkCases: [[PerpsFundingNetwork]] = [[], [.ethereum], [.ethereum, .bsc]]
        for networks in networkCases {
            var passcodeRequests = 0
            var requotes = 0
            var outcome: PerpsDepositOutcome?
            let viewModel = makeViewModel(
                expiresAt: now + 60,
                now: now,
                delegatedNetworks: networks,
                requote: {
                    requotes += 1
                    return Self.reviewed(expiresAt: now + 60)
                }
            ) {
                passcodeRequests += 1
                return "0000"
            }
            viewModel.onPaid = { outcome = $0; changed.send() }

            viewModel.confirm()
            XCTAssertTrue(viewModel.isProcessing)
            await waitUntil { outcome != nil }

            XCTAssertEqual(outcome, .registered(operationId: "op"))
            XCTAssertEqual(passcodeRequests, 1)
            XCTAssertEqual(requotes, 0)
            XCTAssertNil(viewModel.errorText)
            XCTAssertFalse(viewModel.isProcessing)
            viewModel.onDisappear()
        }
    }

    func testOnlyANewPaymentReportsItsConfirmation() async {
        for resumesPayment in [false, true] {
            var confirmed: [String] = []
            var paid = false
            let viewModel = makeViewModel(
                expiresAt: nil,
                now: Date(),
                resumesPayment: resumesPayment,
                pay: { _, _ in .authorizationRequired(operationId: "op-1") }
            ) { "0000" }
            viewModel.onConfirmed = { confirmed.append($0) }
            viewModel.onPaid = { _ in paid = true; changed.send() }

            viewModel.confirm()
            await waitUntil { paid }

            XCTAssertEqual(confirmed, resumesPayment ? [] : ["op-1"])
        }
    }

    func testInsufficientGasNamesTheFeeAsset() {
        XCTAssertEqual(
            PerpsDepositErrorText.text(for: .insufficientNetworkFee(symbol: "ETH"), format: .test),
            TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken("ETH")
        )
        XCTAssertEqual(
            PerpsDepositErrorText.text(for: .insufficientNetworkFee(symbol: "TRX", required: "9.82772"), format: .test),
            TKLocales.Perps.DepositForm.insufficientNetworkFee("TRX", PerpsFormatting.test.plain("9.82772"))
        )
    }

    func testTheBlockAdvisesAnotherWalletOnlyWhenThereIsOne() {
        XCTAssertNotEqual(TKLocales.Perps.DepositForm.addressBlocked, TKLocales.Perps.DepositForm.addressBlockedOnlyWallet)
        XCTAssertEqual(
            PerpsDepositErrorText.text(for: .addressBlocked, format: .test, hasOtherWallets: true),
            TKLocales.Perps.DepositForm.addressBlocked
        )
        XCTAssertEqual(
            PerpsDepositErrorText.text(for: .addressBlocked, format: .test, hasOtherWallets: false),
            TKLocales.Perps.DepositForm.addressBlockedOnlyWallet
        )
    }

    func testCancelingTheUnlockRestoresTheSlider() async {
        let viewModel = makeViewModel(expiresAt: nil, now: Date()) { nil }

        viewModel.confirm()
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertFalse(viewModel.isConfirmationEnabled)
        await waitUntil { viewModel.isConfirmationEnabled }

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertTrue(viewModel.isConfirmationEnabled)
        XCTAssertNil(viewModel.errorText)
    }

    func testTheSliderIsTonedByTheWorstFindingOfTheReview() {
        let cases: [(OperationReview?, TKSlider.Appearance)] = [
            (nil, .standart),
            (Self.review(.info), .standart),
            (Self.review(.warning), .warning),
            (Self.review(.danger), .danger),
        ]
        for (review, appearance) in cases {
            let viewModel = makeViewModel(expiresAt: nil, now: Date(), review: review) { nil }

            XCTAssertEqual(viewModel.confirmAppearance, appearance, "\(String(describing: review?.severity))")
        }
    }

    /// The attempt's consent goes on to the payment, so its final check does not ask again about
    /// what the user accepted on the swipe.
    func testAReviewThatNeedsConsentIsAskedAboutBeforeThePasscode() async {
        let log = EventLog()
        let review = Self.review(.warning)
        var outcome: PerpsDepositOutcome?
        let viewModel = makeViewModel(
            expiresAt: nil,
            now: Date(),
            review: review,
            pay: { _, consent in
                await log.append(consent(review) ? "pay accepted" : "pay refused")
                return .registered(operationId: "op")
            },
            consent: { OperationConsent { _ in await log.append("consent"); return true } }
        ) {
            await log.append("passcode")
            return "0000"
        }
        viewModel.onPaid = { outcome = $0; changed.send() }

        viewModel.confirm()
        await waitUntil { outcome != nil }

        let events = await log.events
        XCTAssertEqual(events, ["consent", "passcode", "pay accepted"])
    }

    func testAReviewWithNothingToShowIsNotAskedAbout() async {
        for review in [nil, Self.review(.info)] {
            let log = EventLog()
            var paid = false
            let viewModel = makeViewModel(
                expiresAt: nil,
                now: Date(),
                review: review,
                consent: { OperationConsent { _ in await log.append("consent"); return false } }
            ) {
                await log.append("passcode")
                return "0000"
            }
            viewModel.onPaid = { _ in paid = true; changed.send() }

            viewModel.confirm()
            await waitUntil { paid }

            let events = await log.events
            XCTAssertEqual(events, ["passcode"], "\(String(describing: review?.severity))")
        }
    }

    /// Declining ends the attempt as a cancelled unlock does: nothing is paid and the quote stays fresh.
    func testADeclinedReviewAsksForNoPasscodeAndQuotesAgain() async {
        let now = Date(timeIntervalSince1970: 100)
        var askedForPasscode = false
        var requotes = 0
        var delays = [TimeInterval]()
        let viewModel = makeViewModel(
            expiresAt: now + 60,
            now: now,
            review: Self.review(.danger),
            pay: { _, _ in
                XCTFail("paid what the user declined")
                return .registered(operationId: "op")
            },
            consent: { OperationConsent { _ in false } },
            requote: {
                requotes += 1
                return Self.reviewed(sourceAmount: "9", expiresAt: now + 60)
            },
            sleep: { delay in
                delays.append(delay)
                changed.send()
                if delays.count > 1 { try await untilCancelled.wait() }
            }
        ) {
            askedForPasscode = true
            return "0000"
        }

        viewModel.confirm()
        await waitUntil { delays.count == 2 }

        XCTAssertEqual(requotes, 1)
        XCTAssertFalse(askedForPasscode)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertNil(viewModel.errorText)
        XCTAssertEqual(delays, [60 - PerpsDepositConfirmViewModel.requoteLead, 60 - PerpsDepositConfirmViewModel.requoteLead])
        viewModel.onDisappear()
    }

    /// The findings can be read past the quote: the passcode is not asked for a payment it would no
    /// longer cover, and the quote is replaced as an expired one is.
    func testAQuoteThatLapsesWhileTheFindingsAreReadIsReplacedBeforeThePasscode() async {
        let clock = TestClock(Date(timeIntervalSince1970: 100))
        var askedForPasscode = false
        var requotes = 0
        let viewModel = makeViewModel(
            expiresAt: clock.now + 60,
            now: clock.now,
            review: Self.review(.warning),
            consent: { OperationConsent { _ in clock.advance(by: 61); return true } },
            requote: {
                requotes += 1
                return Self.reviewed(sourceAmount: "9", expiresAt: clock.now + 60)
            },
            clock: clock
        ) {
            askedForPasscode = true
            return "0000"
        }

        viewModel.confirm()
        await waitUntil { viewModel.rows.contains { $0.value == "9 USDC" } }

        XCTAssertFalse(askedForPasscode)
        XCTAssertEqual(requotes, 1)
        XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .quoteExpired, format: .test))
        XCTAssertTrue(viewModel.isConfirmationEnabled)
        viewModel.onDisappear()
    }

    /// Consent does not outlive its confirmation: swiping again on a quote kept after a failure asks again.
    func testEveryConfirmationAsksAboutTheReviewAgain() async {
        let log = EventLog()
        var attempts = 0
        let viewModel = makeViewModel(
            expiresAt: nil,
            now: Date(),
            review: Self.review(.warning),
            pay: { _, _ in throw CancellationError() },
            consent: {
                attempts += 1
                return OperationConsent { _ in await log.append("consent"); return true }
            }
        ) { "0000" }

        viewModel.confirm()
        await waitUntil { viewModel.errorText != nil }
        viewModel.confirm()
        await waitUntil { viewModel.errorText != nil }

        XCTAssertEqual(attempts, 2)
        let events = await log.events
        XCTAssertEqual(events, ["consent", "consent"])
    }

    /// A review declined after the passcode wrote nothing, so the quote is not kept for a retry as a
    /// payment that may have gone out would be.
    func testAPaymentDeclinedOnItsFinalReviewQuotesAgainWithoutAnError() async {
        let now = Date(timeIntervalSince1970: 100)
        var requotes = 0
        var delays = [TimeInterval]()
        let viewModel = makeViewModel(
            expiresAt: now + 60,
            now: now,
            pay: { _, _ in throw CancellationError() },
            message: { _ in .canceled },
            requote: {
                requotes += 1
                return Self.reviewed(sourceAmount: "9", expiresAt: now + 60)
            },
            sleep: { delay in
                delays.append(delay)
                changed.send()
                if delays.count > 1 { try await untilCancelled.wait() }
            }
        ) { "0000" }

        viewModel.confirm()
        await waitUntil { delays.count == 2 }

        XCTAssertEqual(requotes, 1)
        XCTAssertTrue(viewModel.rows.contains { $0.value == "9 USDC" })
        XCTAssertNil(viewModel.errorText)
        XCTAssertFalse(viewModel.isNoticeError)
        XCTAssertTrue(viewModel.isConfirmationEnabled)
        viewModel.onDisappear()
    }

    func testTheErrorsTheConfirmationShowsAreReportedButNotADeclinedPayment() async {
        for message in [PerpsDepositMessage.failed, .canceled] {
            var failures: [PerpsDepositMessage] = []
            var settled = false
            let viewModel = makeViewModel(
                expiresAt: nil,
                now: Date(),
                pay: { _, _ in throw CancellationError() },
                message: { _ in
                    settled = true
                    changed.send()
                    return message
                }
            ) { "0000" }
            viewModel.onFailure = { failures.append($0) }

            viewModel.confirm()
            await waitUntil { settled && !viewModel.isProcessing }

            XCTAssertEqual(failures, message == .canceled ? [] : [message])
        }
    }

    func testARegionRefusalKeepsTheConfirmationBusyWithoutAnError() async {
        var failures: [PerpsDepositMessage] = []
        let viewModel = makeViewModel(
            expiresAt: nil,
            now: Date(),
            pay: { _, _ in throw CancellationError() },
            message: { _ in .regionRestricted }
        ) { "0000" }
        viewModel.onFailure = {
            failures.append($0)
            changed.send()
        }

        viewModel.confirm()
        await waitUntil { !failures.isEmpty }

        XCTAssertEqual(failures, [.regionRestricted])
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertFalse(viewModel.isConfirmationEnabled)
        XCTAssertNil(viewModel.errorText)
    }

    func testAnExpiredQuoteIsReportedWhenTheConfirmationRefusesIt() {
        var failures: [PerpsDepositMessage] = []
        let viewModel = makeViewModel(expiresAt: Date(timeIntervalSince1970: 100), now: Date(timeIntervalSince1970: 100)) { nil }
        viewModel.onFailure = { failures.append($0) }

        viewModel.confirm()

        XCTAssertEqual(failures, [.quoteExpired])
    }

    func testAFeeNothingCoversIsReportedOnceAsTheConfirmationOpens() {
        let viewModel = feePickerViewModel(Self.feeReviewed(networkFeeUsd: 0.3, feeShortageSymbol: "TRX", picker: FeePickerStub()))
        var failures: [PerpsDepositMessage] = []
        viewModel.onFailure = { failures.append($0) }

        viewModel.onAppear()
        viewModel.onAppear()

        XCTAssertEqual(failures, [.insufficientNetworkFee(symbol: "TRX")])
        viewModel.onDisappear()
    }

    func testAnExpiredQuoteIsRefusedBeforeThePasscodeIsAskedFor() {
        var askedForPasscode = false
        let viewModel = makeViewModel(expiresAt: Date(timeIntervalSince1970: 100), now: Date(timeIntervalSince1970: 100)) {
            askedForPasscode = true
            return nil
        }

        viewModel.confirm()

        XCTAssertFalse(askedForPasscode)
        XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .quoteExpired, format: .test))
        XCTAssertTrue(viewModel.isConfirmationEnabled)
    }

    /// The new terms are shown rather than paid: the user confirms what the screen says.
    func testConfirmingAnExpiredQuoteFetchesANewOneInsteadOfPaying() async {
        let now = Date(timeIntervalSince1970: 100)
        var askedForPasscode = false
        let fresh = Self.reviewed(sourceAmount: "9", expiresAt: now + 60) { _, _ in .registered(operationId: "fresh") }
        let viewModel = makeViewModel(expiresAt: now, now: now, requote: { fresh }) {
            askedForPasscode = true
            return "0000"
        }
        var outcome: PerpsDepositOutcome?
        viewModel.onPaid = { outcome = $0; changed.send() }

        viewModel.confirm()
        await waitUntil { viewModel.rows.contains { $0.value == "9 USDC" } }

        XCTAssertFalse(askedForPasscode)
        XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .quoteExpired, format: .test))
        XCTAssertTrue(viewModel.isConfirmationEnabled)

        viewModel.confirm()
        await waitUntil { outcome != nil }
        XCTAssertEqual(outcome, .registered(operationId: "fresh"))
    }

    func testTheQuoteIsReplacedAheadOfItsExpiry() async {
        let now = Date(timeIntervalSince1970: 100)
        var delays = [TimeInterval]()
        let fresh = Self.reviewed(sourceAmount: "9", creditedAmount: "8.75", expiresAt: now + 60)
        let viewModel = makeViewModel(
            expiresAt: now + 60,
            now: now,
            requote: { fresh },
            sleep: { delay in
                delays.append(delay)
                changed.send()
                if delays.count > 1 { try await untilCancelled.wait() }
            }
        ) { nil }

        viewModel.onAppear()
        await waitUntil { delays.count == 2 }

        XCTAssertEqual(delays, [60 - PerpsDepositConfirmViewModel.requoteLead, 60 - PerpsDepositConfirmViewModel.requoteLead])
        XCTAssertTrue(viewModel.rows.contains { $0.value == "9 USDC" })
        XCTAssertEqual(viewModel.rows.first { $0.id == .minReceived }?.value, "$8.75")
        XCTAssertNil(viewModel.errorText)
        viewModel.onDisappear()
    }

    func testAPaymentRefusedForAnExpiredQuoteIsRequoted() async {
        let now = Date(timeIntervalSince1970: 100)
        let fresh = Self.reviewed(sourceAmount: "9", expiresAt: now + 60)
        let viewModel = makeViewModel(
            expiresAt: now + 60,
            now: now,
            pay: { _, _ in throw CancellationError() },
            message: { _ in .quoteExpired },
            requote: { fresh }
        ) { "0000" }

        viewModel.confirm()
        await waitUntil { viewModel.rows.contains { $0.value == "9 USDC" } }

        XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .quoteExpired, format: .test))
        XCTAssertTrue(viewModel.isConfirmationEnabled)
    }

    func testAPaymentRefusedForACreditThatDroppedShowsTheNewAmountToConfirm() async {
        let now = Date(timeIntervalSince1970: 100)
        var passcodeRequests = 0
        let viewModel = makeViewModel(
            expiresAt: now + 60,
            now: now,
            pay: { _, _ in throw CancellationError() },
            message: { _ in .quoteChanged },
            requote: { Self.reviewed(creditedAmount: "9.5", expiresAt: now + 60) }
        ) {
            passcodeRequests += 1
            return "0000"
        }

        viewModel.confirm()
        await waitUntil { viewModel.rows.contains { $0.id == .minReceived && $0.value == PerpsFormatting.test.usd("9.5") } }

        XCTAssertEqual(viewModel.errorText, TKLocales.Perps.DepositForm.quoteChanged)
        XCTAssertTrue(viewModel.isNoticeError)
        XCTAssertTrue(viewModel.isConfirmationEnabled)
        XCTAssertEqual(passcodeRequests, 1)
        viewModel.onDisappear()
    }

    func testAnExpiredRequoteStopsAndCanBeRetriedManually() async {
        let now = Date(timeIntervalSince1970: 100)
        for expiresAt in [now - 1, now] {
            var requotes = 0
            var delays = [TimeInterval]()
            var askedForPasscode = false
            let expired = Self.reviewed(sourceAmount: "9", expiresAt: expiresAt)
            let fresh = Self.reviewed(sourceAmount: "8", expiresAt: now + 60)
            let viewModel = makeViewModel(
                expiresAt: now,
                now: now,
                requote: {
                    requotes += 1
                    return requotes == 1 ? expired : fresh
                },
                sleep: { delay in
                    delays.append(delay)
                    changed.send()
                    if delays.count > 1 { throw CancellationError() }
                }
            ) {
                askedForPasscode = true
                return "0000"
            }

            viewModel.onAppear()
            await waitUntil { viewModel.errorText != nil }

            XCTAssertEqual(requotes, 1)
            XCTAssertEqual(delays, [0])
            XCTAssertTrue(viewModel.rows.contains { $0.value == "10 USDC" })
            XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .quoteExpired, format: .test))
            XCTAssertTrue(viewModel.isConfirmationEnabled)
            XCTAssertFalse(askedForPasscode)

            viewModel.confirm()
            await waitUntil { viewModel.rows.contains { $0.value == "8 USDC" } }

            XCTAssertEqual(requotes, 2)
            XCTAssertTrue(viewModel.isConfirmationEnabled)
            XCTAssertFalse(askedForPasscode)
            viewModel.onDisappear()
        }
    }

    /// Any other failure may have reached the chain; its retry is matched to the payment by the
    /// quote, so a new quote could pay twice.
    func testAPaymentThatFailedOtherwiseKeepsItsQuote() async {
        let now = Date(timeIntervalSince1970: 100)
        var requotes = 0
        let viewModel = makeViewModel(
            expiresAt: now + 60,
            now: now,
            pay: { _, _ in throw CancellationError() },
            message: { _ in .failed },
            requote: {
                requotes += 1
                return Self.reviewed(sourceAmount: "9", expiresAt: now + 60)
            },
            sleep: { _ in }
        ) { "0000" }

        viewModel.confirm()
        await waitUntil { viewModel.errorText != nil }
        viewModel.onAppear()
        await viewModel.requoteTask?.value

        XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .failed, format: .test))
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(requotes, 0)
    }

    /// The payment runs in a main-actor task that cannot start before this test yields, so
    /// leaving is tried while it is still underway.
    func testLeavingIsIgnoredWhileAPaymentIsUnderway() {
        let viewModel = makeViewModel(expiresAt: nil, now: Date()) { nil }
        var left = false
        viewModel.onBack = { left = true }
        viewModel.onClose = { left = true }

        viewModel.confirm()
        viewModel.back()
        viewModel.close()

        XCTAssertFalse(left)
    }

    func testUnfinishedPaymentStillShowsNetworkFeeWhileRegistrationDoesNot() {
        let payment = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), resumesPayment: true) { nil }
        let registration = makeViewModel(expiresAt: nil, now: Date(), resumesPayment: true) { nil }
        XCTAssertTrue(payment.rows.contains { $0.id == .networkFee })
        XCTAssertFalse(registration.rows.contains { $0.id == .networkFee })
        XCTAssertEqual(registration.rows.first { $0.id == .minReceived }?.value, "$10")
    }

    func testUSDCSourceAndMinimumUseTheSameDollarValue() {
        let viewModel = PerpsDepositConfirmViewModel(
            reviewed: Self.reviewed(sourceAmount: "1.5", expiresAt: nil),
            walletName: "Wallet",
            source: PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum),
            balance: .init(amount: "10", usdPrice: 1, iconURL: nil),
            format: .test,
            message: { _ in .failed },
            passcodeProvider: { nil },
            consent: { .refuse }
        )

        XCTAssertEqual(viewModel.rows.first { $0.id == .totalAmount }?.subValue, "$1.50")
        XCTAssertEqual(viewModel.rows.first { $0.id == .minReceived }?.value, "$1.50")
    }

    func testADepositFromTonShowsWhatItsMessageCarriesAndWhoItGoesTo() throws {
        let terms = PerpsDepositTerms(
            sourceAmount: "1.4",
            sourceSymbol: "GRAM",
            creditedAmount: "1.66",
            creditedSymbol: "USDC",
            networkFee: "0.003",
            networkFeeSymbol: "GRAM",
            sentAmount: "1.398210269",
            provider: "Relay"
        )
        let viewModel = PerpsDepositConfirmViewModel(
            reviewed: PerpsReviewedDeposit(terms: terms) { _, _ in .registered(operationId: "op") },
            walletName: "Wallet",
            source: PerpsDepositSource(assetId: "ton/mainnet/coin", symbol: "GRAM", decimals: 9, network: .ton),
            balance: .init(amount: "10", usdPrice: 2, iconURL: nil),
            format: .test,
            message: { _ in .failed },
            passcodeProvider: { nil },
            consent: { .refuse }
        )

        XCTAssertEqual(viewModel.rows.map(\.id), [.wallet, .totalAmount, .toPerpsAccount, .minReceived, .provider, .networkFee])
        let sent = try XCTUnwrap(viewModel.rows.first { $0.id == .totalAmount })
        XCTAssertEqual(sent.value, "\(PerpsFormatting.test.plain("1.398210269")) GRAM")
        XCTAssertEqual(sent.subValue, PerpsFundingConfirmRows.usd("1.398210269", price: 2, format: .test))
        let provider = try XCTUnwrap(viewModel.rows.first { $0.id == .provider })
        XCTAssertEqual(provider.title, TKLocales.NativeSwap.Screen.Confirm.Field.provider)
        XCTAssertEqual(provider.value, "Relay")
    }

    func testArrivalTimeIsShownOnlyWhenTheQuoteEstimatesIt() {
        let estimated = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), estimatedDurationSeconds: 61) { nil }
        let unknown = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date()) { nil }
        XCTAssertEqual(estimated.rows.first { $0.id == .arrivalTime }?.value, TKLocales.Ramp.Deposit.upToMin(2))
        let p80 = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), estimatedDurationSeconds: 120) { nil }
        XCTAssertEqual(p80.rows.first { $0.id == .arrivalTime }?.value, TKLocales.Ramp.Deposit.upToMin(2))
        XCTAssertEqual(estimated.rows.map(\.id), [.wallet, .totalAmount, .toPerpsAccount, .minReceived, .networkFee, .arrivalTime])
        XCTAssertEqual(estimated.rows.first { $0.id == .arrivalTime }?.titleHint, TKLocales.Perps.DepositForm.arrivalTimeInfo)
        XCTAssertEqual(unknown.rows.map(\.id), [.wallet, .totalAmount, .toPerpsAccount, .minReceived, .networkFee])
        XCTAssertEqual(unknown.rows.first { $0.id == .totalAmount }?.title, TKLocales.Perps.Funding.youSend)
        XCTAssertEqual(unknown.rows.first { $0.id == .toPerpsAccount }?.value, "≈ $10")
        XCTAssertEqual(unknown.rows.first { $0.id == .minReceived }?.title, TKLocales.Perps.Confirm.minReceived)
        XCTAssertEqual(unknown.rows.first { $0.id == .minReceived }?.value, "$10")
    }

    /// With the fee's parts unknown the network fee row is the only fee left to explain the setup on.
    func testOnlyTheDepositThatCreatesTheAccountExplainsTheSetupOnItsFee() {
        let first = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), estimatedDurationSeconds: 120, createsAccount: true) { nil }
        let later = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), estimatedDurationSeconds: 120) { nil }

        XCTAssertEqual(first.rows.first { $0.id == .networkFee }?.titleHint, TKLocales.Perps.DepositForm.accountSetupNote)
        XCTAssertNil(later.rows.first { $0.id == .networkFee }?.titleHint)
        for viewModel in [first, later] {
            XCTAssertNil(viewModel.rows.first { $0.id == .arrivalTime }?.note)
        }

        let priced = tronViewModel(networkFeeUsd: 0.3, destinationGasUsd: 0.9, providerUsd: 0.3, createsAccount: true)
        XCTAssertEqual(priced.rows.first { $0.id == .fee }?.titleHint, TKLocales.Perps.DepositForm.activationFeeDetails("$1.20", "$0.30"))
    }

    func testADepositThatDelegatesTheAddressNamesItsNetworks() {
        let delegating = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), delegatedNetworks: [.ethereum, .bsc]) { nil }
        let plain = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date()) { nil }
        XCTAssertEqual(
            delegating.noticeText,
            TKLocales.Perps.DepositForm.delegationNotice("\(PerpsFundingNetwork.ethereum.displayName), \(PerpsFundingNetwork.bsc.displayName)")
        )
        XCTAssertNil(plain.noticeText)
    }

    /// The notice that sends the user back to the amount must not hide what the next
    /// confirmation signs.
    func testARequoteThatBringsADelegationInSaysSoBelowItsNotice() async throws {
        let now = Date(timeIntervalSince1970: 100)
        let fresh = Self.reviewed(sourceAmount: "9", expiresAt: now + 60, delegatedNetworks: [.ethereum])
        let viewModel = makeViewModel(expiresAt: now, now: now, requote: { fresh }) { "0000" }
        let expired = try XCTUnwrap(PerpsDepositErrorText.text(for: .quoteExpired, format: .test))

        viewModel.confirm()
        await waitUntil { viewModel.rows.contains { $0.value == "9 USDC" } }

        XCTAssertEqual(
            viewModel.noticeText,
            expired + "\n" + TKLocales.Perps.DepositForm.delegationNotice(PerpsFundingNetwork.ethereum.displayName)
        )
    }

    /// Measured by the Fee row: the swap's rate below the source's value is not counted.
    func testADepositLosingFifteenPercentToFeesIsWarnedAbout() {
        let costly = tronViewModel(networkFeeUsd: 0.3, destinationGasUsd: 0.9, providerUsd: 0.3)
        XCTAssertEqual(costly.noticeText, TKLocales.Perps.Funding.highFee(15))
        XCTAssertTrue(costly.isNoticeWarning)

        let cheap = tronViewModel(credited: "5", networkFeeUsd: 0.3, destinationGasUsd: 0.1, providerUsd: 0.1)
        XCTAssertNil(cheap.noticeText)
        XCTAssertFalse(cheap.isNoticeWarning)
    }

    /// The destination gas is network fee too, so the provider's line holds only what it keeps.
    func testTheFeeRowPutsTheGasOfBothChainsUnderTheNetworkFee() {
        let priced = tronViewModel(networkFeeUsd: 0.3, destinationGasUsd: 0.9, providerUsd: 0.3)
        let fee = priced.rows.first { $0.id == .fee }
        XCTAssertEqual(fee?.title, TKLocales.Perps.Funding.fees)
        XCTAssertEqual(fee?.value, "≈ $1.50 · TRX")
        XCTAssertEqual(fee?.valueParts, [
            .init(text: "≈ $1.50 · ", tone: .neutral),
            .init(text: "TRX", tone: .accent),
        ])
        XCTAssertEqual(fee?.titleHint, TKLocales.Perps.DepositForm.feeDetails("$1.20", "$0.30"))
        XCTAssertFalse(priced.rows.contains { $0.id == .networkFee })
    }

    func testAnUnknownPartLeavesTheNetworkFeeAlone() {
        let gasUnpriced = tronViewModel(networkFeeUsd: nil, destinationGasUsd: 0.9, providerUsd: 0.3)
        let providerUnknown = tronViewModel(networkFeeUsd: 0.3, destinationGasUsd: nil, providerUsd: nil)
        for viewModel in [gasUnpriced, providerUnknown] {
            XCTAssertFalse(viewModel.rows.contains { $0.id == .fee })
            let networkFee = viewModel.rows.first { $0.id == .networkFee }
            XCTAssertEqual(networkFee?.title, TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee)
            XCTAssertNil(networkFee?.titleHint)
        }
    }

    func testKnownFeesStillWarnWhenAnotherPartIsUnknown() {
        let gasUnpriced = tronViewModel(networkFeeUsd: nil, destinationGasUsd: 1.2, providerUsd: 0.3)
        let providerUnknown = tronViewModel(networkFeeUsd: 1.5, destinationGasUsd: nil, providerUsd: nil)
        for viewModel in [gasUnpriced, providerUnknown] {
            XCTAssertEqual(viewModel.noticeText, TKLocales.Perps.Funding.highFee(15))
            XCTAssertTrue(viewModel.isNoticeWarning)
        }
    }

    func testUnknownOrKnownLowFeesDoNotWarn() {
        let unknown = tronViewModel(networkFeeUsd: nil, destinationGasUsd: nil, providerUsd: nil)
        let gasUnpriced = tronViewModel(networkFeeUsd: nil, destinationGasUsd: 1.2, providerUsd: 0.29)
        let providerUnknown = tronViewModel(networkFeeUsd: 1.49, destinationGasUsd: nil, providerUsd: nil)
        for viewModel in [unknown, gasUnpriced, providerUnknown] {
            XCTAssertNil(viewModel.noticeText)
            XCTAssertFalse(viewModel.isNoticeWarning)
        }
    }

    func testAFeeWithAChoiceNamesItsMethodBehindASwitchAndAPickShowsTheTermsForIt() {
        let picker = FeePickerStub()
        let viewModel = feePickerViewModel(Self.feeReviewed(networkFeeUsd: 0.3, picker: picker))

        let fee = viewModel.rows.first { $0.id == .fee }
        XCTAssertEqual(fee?.showsFeePicker, true)
        XCTAssertEqual(fee?.value, "≈ $1.50")
        XCTAssertEqual(fee?.feeMethod, "TRX")
        XCTAssertEqual(fee?.titleHint, TKLocales.Perps.DepositForm.feeDetails("$1.20", "$0.30"))

        viewModel.pickFee()
        picker.pick(Self.feeReviewed(networkFeeUsd: 0.1, feeMethodTitle: "Battery", picker: picker))

        let picked = viewModel.rows.first { $0.id == .fee }
        XCTAssertEqual(picked?.value, "≈ $1.30")
        XCTAssertEqual(picked?.feeMethod, "Battery")
    }

    /// Charges have no dollar price, so they stand in their own row and the dollars of the delivery
    /// and of the provider in the next one.
    func testBatteryChargesStandApartFromTheDollarFees() {
        let viewModel = batteryViewModel(networkFee: "12", destinationGasUsd: 0.9, providerUsd: 0.3)

        let charges = viewModel.rows.first { $0.id == .fee }
        XCTAssertEqual(charges?.title, TKLocales.Perps.DepositForm.networkFees)
        XCTAssertEqual(charges?.value, "≈ 12 charges")
        XCTAssertNil(charges?.subValue)
        XCTAssertEqual(charges?.feeMethod, "Battery")
        XCTAssertNil(charges?.titleHint)
        let dollars = viewModel.rows.first { $0.id == .providerFee }
        XCTAssertEqual(dollars?.title, TKLocales.Perps.Funding.fees)
        XCTAssertEqual(dollars?.value, "≈ $1.20")
        XCTAssertEqual(dollars?.titleHint, TKLocales.Perps.DepositForm.feeDetails("$0.90", "$0.30"))
        XCTAssertFalse(viewModel.rows.contains { $0.id == .temporaryReserve })
    }

    /// Their dollars only weigh the fee against the amount.
    func testPricedBatteryChargesStillLeadTheFee() {
        let viewModel = batteryViewModel(networkFee: "664", networkFeeUsd: 2.3, destinationGasUsd: 0.1, providerUsd: 0.2)

        XCTAssertEqual(viewModel.rows.first { $0.id == .fee }?.value, "≈ 664 charges")
        XCTAssertEqual(viewModel.rows.first { $0.id == .providerFee }?.value, "≈ $0.30")
    }

    func testWhatBatteryHoldsBackIsShownApartFromTheFee() {
        let viewModel = batteryViewModel(networkFee: "20", reserve: "5 charges", destinationGasUsd: 4, providerUsd: 0, createsAccount: true)

        XCTAssertEqual(viewModel.rows.map(\.id), [.wallet, .totalAmount, .toPerpsAccount, .minReceived, .fee, .activationFee, .temporaryReserve])
        let reserve = viewModel.rows.first { $0.id == .temporaryReserve }
        XCTAssertEqual(reserve?.title, TKLocales.MultichainSwap.Screen.Confirm.Field.temporaryReserve)
        XCTAssertEqual(reserve?.value, "≈ 5 charges")
        XCTAssertEqual(reserve?.titleHint, TKLocales.Perps.DepositForm.temporaryReserveInfo("5 charges"))
    }

    /// An existing account is credited without a call on Ethereum, so on the deposit that creates
    /// the account the delivery gas is the setup's price and leaves the provider's fee alone.
    func testTheAccountSetupIsPricedApartFromTheProviderFee() {
        let viewModel = batteryViewModel(networkFee: "20", destinationGasUsd: 4, providerUsd: 0.3, createsAccount: true)

        XCTAssertEqual(viewModel.rows.map(\.id), [.wallet, .totalAmount, .toPerpsAccount, .minReceived, .fee, .activationFee, .providerFee])
        let activation = viewModel.rows.first { $0.id == .activationFee }
        XCTAssertEqual(activation?.title, TKLocales.Perps.DepositForm.activationFee)
        XCTAssertEqual(activation?.value, "≈ \(PerpsFormatting.test.tokenCompact(4, symbol: "USDC"))")
        XCTAssertEqual(activation?.titleHint, TKLocales.Perps.DepositForm.activationFeeInfo)
        let provider = viewModel.rows.first { $0.id == .providerFee }
        XCTAssertEqual(provider?.value, "≈ $0.30")
        XCTAssertNil(provider?.titleHint)
        XCTAssertNil(viewModel.rows.first { $0.id == .fee }?.titleHint)
    }

    /// Without delivery gas nothing prices the setup, so no row claims it costs nothing.
    func testAnUnpricedAccountSetupGetsNoRow() {
        let viewModel = batteryViewModel(networkFee: "20", destinationGasUsd: 0, providerUsd: 0.3, createsAccount: true)

        XCTAssertFalse(viewModel.rows.contains { $0.id == .activationFee })
        XCTAssertEqual(viewModel.rows.first { $0.id == .providerFee }?.value, "≈ $0.30")
        XCTAssertNil(viewModel.rows.first { $0.id == .providerFee }?.titleHint)
    }

    /// No dollars to carry the setup's hint: the charges row explains it.
    func testTheChargesNeverClaimToPayTheAccountSetup() {
        let viewModel = batteryViewModel(networkFee: "20", destinationGasUsd: 0, providerUsd: 0, createsAccount: true)

        XCTAssertFalse(viewModel.rows.contains { $0.id == .providerFee })
        XCTAssertNil(viewModel.rows.first { $0.id == .fee }?.titleHint)
    }

    func testAFeeWithoutAChoiceKeepsItsPlainRow() {
        let viewModel = feePickerViewModel(Self.feeReviewed(networkFeeUsd: 0.3, picker: nil))

        let fee = viewModel.rows.first { $0.id == .fee }
        XCTAssertEqual(fee?.showsFeePicker, false)
        XCTAssertEqual(fee?.value, "≈ $1.50 · TRX")
    }

    /// The pick was priced on the quote the picker opened over: once a requote replaced it, the
    /// screen asks again rather than show the old quote under the new method.
    func testAPickArrivingAfterARequoteReplacedTheReviewAsksAgain() async {
        let now = Date(timeIntervalSince1970: 100)
        let picker = FeePickerStub()
        var requotes = 0
        let viewModel = feePickerViewModel(
            Self.feeReviewed(networkFeeUsd: 0.3, expiresAt: now, picker: picker),
            now: now,
            requote: {
                requotes += 1
                return Self.feeReviewed(networkFeeUsd: 0.3, expiresAt: now + 60, picker: picker)
            }
        )

        viewModel.pickFee()
        viewModel.confirm()
        await waitUntil { requotes == 1 && viewModel.isConfirmationEnabled }
        picker.pick(Self.feeReviewed(networkFeeUsd: 0.1, feeMethodTitle: "Battery", expiresAt: now, picker: picker))
        await waitUntil { requotes == 2 && viewModel.isConfirmationEnabled }

        XCTAssertEqual(viewModel.rows.first { $0.id == .fee }?.feeMethod, "TRX")
        viewModel.onDisappear()
    }

    /// Nothing covers the fee: the screen says so as a swap does, and confirming opens the picker,
    /// where each method is topped up, instead of paying.
    func testAFeeNothingCoversIsNamedAndConfirmingOpensThePickerInsteadOfPaying() {
        let picker = FeePickerStub()
        let viewModel = feePickerViewModel(Self.feeReviewed(networkFeeUsd: 0.3, feeShortageSymbol: "TRX", picker: picker))

        XCTAssertEqual(viewModel.noticeText, TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken("TRX"))
        XCTAssertTrue(viewModel.isNoticeError)
        XCTAssertFalse(viewModel.isNoticeWarning)

        viewModel.confirm()

        XCTAssertNotNil(picker.picked)
        XCTAssertFalse(viewModel.isProcessing)
    }

    /// A top-up changes what can pay, so the methods are priced again on a fresh quote.
    func testATopUpQuotesAgain() async {
        let picker = FeePickerStub()
        var requotes = 0
        let viewModel = feePickerViewModel(
            Self.feeReviewed(networkFeeUsd: 0.3, feeShortageSymbol: "TRX", picker: picker),
            requote: {
                requotes += 1
                return Self.feeReviewed(networkFeeUsd: 0.3, picker: picker)
            }
        )

        viewModel.pickFee()
        picker.refilled()
        await waitUntil { requotes == 1 && viewModel.isConfirmationEnabled }

        XCTAssertNil(viewModel.noticeText)
        viewModel.onDisappear()
    }

    private func feePickerViewModel(
        _ reviewed: PerpsReviewedDeposit,
        now: Date = Date(),
        requote: (() async throws -> PerpsReviewedDeposit)? = nil
    ) -> PerpsDepositConfirmViewModel {
        let viewModel = PerpsDepositConfirmViewModel(
            reviewed: reviewed,
            walletName: "Wallet",
            source: PerpsDepositSource(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron),
            balance: nil,
            format: .test,
            message: { _ in .failed },
            passcodeProvider: { nil },
            consent: { .refuse },
            requote: requote.map { requote in { defer { changed.send() }; return try await requote() } },
            now: { now },
            sleep: { _ in try await untilCancelled.wait() }
        )
        viewModel.objectWillChange.sink { changed.send() }.store(in: &subscriptions)
        return viewModel
    }

    private static func feeReviewed(
        networkFeeUsd: Decimal,
        feeMethodTitle: String? = nil,
        feeShortageSymbol: String? = nil,
        expiresAt: Date = Date().addingTimeInterval(60),
        picker: FeePickerStub?
    ) -> PerpsReviewedDeposit {
        PerpsReviewedDeposit(
            terms: PerpsDepositTerms(
                sourceAmount: "20",
                sourceSymbol: "TRX",
                creditedAmount: "8.8",
                creditedSymbol: "USDC",
                networkFee: "1",
                networkFeeSymbol: "TRX",
                networkFeeUsd: networkFeeUsd,
                feeMethodTitle: feeMethodTitle,
                feeShortageSymbol: feeShortageSymbol,
                providerFees: PerpsDepositProviderFees(destinationGasUsd: 0.9, providerUsd: 0.3),
                expiresAt: expiresAt
            ),
            pickFee: picker.map { picker in { picker.picked = $0 } },
            pay: { _, _ in .registered(operationId: "op") }
        )
    }

    private func batteryViewModel(
        networkFee: String,
        networkFeeUsd: Decimal? = nil,
        reserve: String? = nil,
        destinationGasUsd: Decimal,
        providerUsd: Decimal,
        createsAccount: Bool = false
    ) -> PerpsDepositConfirmViewModel {
        feePickerViewModel(PerpsReviewedDeposit(
            terms: PerpsDepositTerms(
                sourceAmount: "20",
                sourceSymbol: "USDT",
                creditedAmount: "19",
                creditedSymbol: "USDC",
                networkFee: networkFee,
                networkFeeSymbol: "charges",
                networkFeeUsd: networkFeeUsd,
                feeMethodTitle: "Battery",
                paysFeeInCharges: true,
                networkFeeReserve: reserve,
                providerFees: PerpsDepositProviderFees(destinationGasUsd: destinationGasUsd, providerUsd: providerUsd),
                createsAccount: createsAccount
            ),
            pickFee: { _ in },
            pay: { _, _ in .registered(operationId: "op") }
        ))
    }

    private func tronViewModel(
        credited: String = "8.8",
        networkFeeUsd: Decimal?,
        destinationGasUsd: Decimal?,
        providerUsd: Decimal?,
        createsAccount: Bool = false
    ) -> PerpsDepositConfirmViewModel {
        let providerFees = destinationGasUsd.flatMap { gas in
            providerUsd.map { PerpsDepositProviderFees(destinationGasUsd: gas, providerUsd: $0) }
        }
        return PerpsDepositConfirmViewModel(
            reviewed: PerpsReviewedDeposit(
                terms: PerpsDepositTerms(
                    sourceAmount: "20",
                    sourceSymbol: "TRX",
                    creditedAmount: credited,
                    creditedSymbol: "USDC",
                    networkFee: "1",
                    networkFeeSymbol: "TRX",
                    networkFeeUsd: networkFeeUsd,
                    providerFees: providerFees,
                    expiresAt: Date().addingTimeInterval(60),
                    createsAccount: createsAccount
                ),
                pay: { _, _ in .registered(operationId: "op") }
            ),
            walletName: "Wallet",
            source: PerpsDepositSource(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron),
            balance: PerpsFundingBalance(amount: "100", usdPrice: 0.5, iconURL: nil),
            format: .test,
            message: { _ in .failed },
            passcodeProvider: { nil },
            consent: { .refuse }
        )
    }

    private func makeViewModel(
        expiresAt: Date?,
        now: Date,
        resumesPayment: Bool = false,
        estimatedDurationSeconds: Int? = nil,
        delegatedNetworks: [PerpsFundingNetwork] = [],
        createsAccount: Bool = false,
        review: OperationReview? = nil,
        pay: @escaping @Sendable (String, OperationConsent) async throws -> PerpsDepositOutcome = { _, _ in .registered(operationId: "op") },
        message: @escaping (Error) -> PerpsDepositMessage = { _ in .failed },
        consent: @escaping @MainActor () -> OperationConsent = { .refuse },
        requote: (() async throws -> PerpsReviewedDeposit)? = nil,
        sleep: @escaping (TimeInterval) async throws -> Void = { _ in try await untilCancelled.wait() },
        clock: TestClock? = nil,
        passcode: @escaping () async -> String?
    ) -> PerpsDepositConfirmViewModel {
        let viewModel = PerpsDepositConfirmViewModel(
            reviewed: Self.reviewed(
                expiresAt: expiresAt,
                resumesPayment: resumesPayment,
                estimatedDurationSeconds: estimatedDurationSeconds,
                delegatedNetworks: delegatedNetworks,
                createsAccount: createsAccount,
                review: review,
                pay: pay
            ),
            walletName: "Wallet",
            source: PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum),
            balance: nil,
            format: .test,
            message: { defer { changed.send() }; return message($0) },
            passcodeProvider: { defer { changed.send() }; return await passcode() },
            consent: consent,
            requote: requote.map { requote in { defer { changed.send() }; return try await requote() } },
            now: { clock?.now ?? now },
            sleep: sleep
        )
        viewModel.objectWillChange.sink { changed.send() }.store(in: &subscriptions)
        return viewModel
    }

    private nonisolated static func reviewed(
        sourceAmount: String = "10",
        sourceSymbol: String = "USDC",
        creditedAmount: String? = nil,
        expiresAt: Date?,
        resumesPayment: Bool = false,
        estimatedDurationSeconds: Int? = nil,
        delegatedNetworks: [PerpsFundingNetwork] = [],
        createsAccount: Bool = false,
        review: OperationReview? = nil,
        pay: @escaping @Sendable (String, OperationConsent) async throws -> PerpsDepositOutcome = { _, _ in .registered(operationId: "op") }
    ) -> PerpsReviewedDeposit {
        PerpsReviewedDeposit(
            terms: PerpsDepositTerms(
                sourceAmount: sourceAmount,
                sourceSymbol: sourceSymbol,
                creditedAmount: creditedAmount ?? sourceAmount,
                creditedSymbol: "USDC",
                networkFee: nil,
                networkFeeSymbol: "ETH",
                resumesPayment: resumesPayment,
                expiresAt: expiresAt,
                estimatedDurationSeconds: estimatedDurationSeconds,
                delegatedNetworks: delegatedNetworks,
                createsAccount: createsAccount
            ),
            review: review,
            pay: pay
        )
    }

    private nonisolated static func review(_ severity: OperationFinding.Severity) -> OperationReview {
        OperationReview(id: "review", findings: [OperationFinding(id: "finding", kind: "Stub", severity: severity, title: "Finding")])
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line, condition: () -> Bool) async {
        await TKTestSupport.waitUntil(changed, file: file, line: line) { condition() }
    }
}

@MainActor
private final class FeePickerStub {
    var picked: (@MainActor (PerpsReviewedDeposit?) -> Void)?

    func pick(_ reviewed: PerpsReviewedDeposit) {
        picked?(reviewed)
    }

    func refilled() {
        picked?(nil)
    }
}

private actor EventLog {
    private(set) var events = [String]()

    func append(_ event: String) {
        events.append(event)
    }
}

/// What the screen reads as now, moved from the task that asks for consent.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current += interval
    }
}
