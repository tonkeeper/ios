@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsDepositConfirmViewModelTests: XCTestCase {
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
            viewModel.onPaid = { outcome = $0 }

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
        let fresh = Self.reviewed(sourceAmount: "9", expiresAt: now + 60) { _ in .registered(operationId: "fresh") }
        let viewModel = makeViewModel(expiresAt: now, now: now, requote: { fresh }) {
            askedForPasscode = true
            return "0000"
        }
        var outcome: PerpsDepositOutcome?
        viewModel.onPaid = { outcome = $0 }

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
                if delays.count > 1 { try await Task.sleep(nanoseconds: 3_600_000_000_000) }
            }
        ) { nil }

        viewModel.onAppear()
        await waitUntil { viewModel.rows.contains { $0.value == "9 USDC" } }

        XCTAssertEqual(delays, [60 - PerpsDepositConfirmViewModel.requoteLead, 60 - PerpsDepositConfirmViewModel.requoteLead])
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
            pay: { _ in throw CancellationError() },
            message: { _ in .quoteExpired },
            requote: { fresh }
        ) { "0000" }

        viewModel.confirm()
        await waitUntil { viewModel.rows.contains { $0.value == "9 USDC" } }

        XCTAssertEqual(viewModel.errorText, PerpsDepositErrorText.text(for: .quoteExpired, format: .test))
        XCTAssertTrue(viewModel.isConfirmationEnabled)
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
            pay: { _ in throw CancellationError() },
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
        try? await Task.sleep(nanoseconds: 50_000_000)

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

    func testArrivalTimeIsShownOnlyWhenTheQuoteEstimatesIt() {
        let estimated = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date(), estimatedDurationSeconds: 61) { nil }
        let unknown = makeViewModel(expiresAt: Date().addingTimeInterval(60), now: Date()) { nil }
        XCTAssertEqual(estimated.rows.first { $0.id == .arrivalTime }?.value, TKLocales.Ramp.Deposit.upToMin(2))
        XCTAssertEqual(estimated.rows.map(\.id), [.wallet, .totalAmount, .networkFee, .minReceived, .arrivalTime])
        XCTAssertEqual(unknown.rows.map(\.id), [.wallet, .totalAmount, .networkFee, .minReceived])
        XCTAssertEqual(unknown.rows.first { $0.id == .minReceived }?.title, TKLocales.Perps.Confirm.minReceived)
        XCTAssertEqual(unknown.rows.first { $0.id == .minReceived }?.value, "$10")
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

    /// What the source is worth beyond the USDC credited is fee too, so a swap's spread counts.
    func testADepositLosingFifteenPercentToFeesIsWarnedAbout() {
        func viewModel(credited: String, networkFeeUsd: Decimal?) -> PerpsDepositConfirmViewModel {
            PerpsDepositConfirmViewModel(
                reviewed: PerpsReviewedDeposit(
                    terms: PerpsDepositTerms(
                        sourceAmount: "20",
                        sourceSymbol: "TRX",
                        creditedAmount: credited,
                        creditedSymbol: "USDC",
                        networkFee: "1",
                        networkFeeSymbol: "TRX",
                        networkFeeUsd: networkFeeUsd,
                        expiresAt: Date().addingTimeInterval(60)
                    ),
                    pay: { _ in .registered(operationId: "op") }
                ),
                walletName: "Wallet",
                source: PerpsDepositSource(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, network: .tron),
                balance: PerpsFundingBalance(amount: "100", usdPrice: 0.5, iconURL: nil),
                format: .test,
                message: { _ in .failed },
                passcodeProvider: { nil }
            )
        }

        let costly = viewModel(credited: "8.8", networkFeeUsd: 0.3)
        XCTAssertEqual(costly.noticeText, TKLocales.Perps.Funding.highFee(15))
        XCTAssertTrue(costly.isNoticeWarning)

        let cheap = viewModel(credited: "9.5", networkFeeUsd: 0.3)
        XCTAssertNil(cheap.noticeText)
        XCTAssertFalse(cheap.isNoticeWarning)
    }

    private func makeViewModel(
        expiresAt: Date?,
        now: Date,
        resumesPayment: Bool = false,
        estimatedDurationSeconds: Int? = nil,
        delegatedNetworks: [PerpsFundingNetwork] = [],
        pay: @escaping @Sendable (String) async throws -> PerpsDepositOutcome = { _ in .registered(operationId: "op") },
        message: @escaping (Error) -> PerpsDepositMessage = { _ in .failed },
        requote: (() async throws -> PerpsReviewedDeposit)? = nil,
        sleep: @escaping (TimeInterval) async throws -> Void = { _ in try await Task.sleep(nanoseconds: 3_600_000_000_000) },
        passcode: @escaping () async -> String?
    ) -> PerpsDepositConfirmViewModel {
        PerpsDepositConfirmViewModel(
            reviewed: Self.reviewed(
                expiresAt: expiresAt,
                resumesPayment: resumesPayment,
                estimatedDurationSeconds: estimatedDurationSeconds,
                delegatedNetworks: delegatedNetworks,
                pay: pay
            ),
            walletName: "Wallet",
            source: PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum),
            balance: nil,
            format: .test,
            message: message,
            passcodeProvider: passcode,
            requote: requote,
            now: { now },
            sleep: sleep
        )
    }

    private nonisolated static func reviewed(
        sourceAmount: String = "10",
        creditedAmount: String? = nil,
        expiresAt: Date?,
        resumesPayment: Bool = false,
        estimatedDurationSeconds: Int? = nil,
        delegatedNetworks: [PerpsFundingNetwork] = [],
        pay: @escaping @Sendable (String) async throws -> PerpsDepositOutcome = { _ in .registered(operationId: "op") }
    ) -> PerpsReviewedDeposit {
        PerpsReviewedDeposit(
            terms: PerpsDepositTerms(
                sourceAmount: sourceAmount,
                sourceSymbol: "USDC",
                creditedAmount: creditedAmount ?? sourceAmount,
                creditedSymbol: "USDC",
                networkFee: nil,
                networkFeeSymbol: "ETH",
                resumesPayment: resumesPayment,
                expiresAt: expiresAt,
                estimatedDurationSeconds: estimatedDurationSeconds,
                delegatedNetworks: delegatedNetworks
            ),
            pay: pay
        )
    }

    private func waitUntil(timeout: TimeInterval = 2, condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !condition() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
