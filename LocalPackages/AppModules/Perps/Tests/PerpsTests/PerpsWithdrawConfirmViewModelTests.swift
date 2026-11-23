@testable import Perps
import PerpsModels
import TKLocalize
import TKTestSupport
import XCTest

@MainActor
final class PerpsWithdrawConfirmViewModelTests: XCTestCase {
    func testAWithdrawalShowsTheBackendEstimateRoundedUpToMinutes() {
        let viewModel = makeViewModel(relayed: false, network: .ethereum, estimatedDurationSeconds: 1072)

        XCTAssertEqual(arrivalTime(viewModel), TKLocales.Ramp.Deposit.upToMin(18))
        XCTAssertNil(viewModel.rows.first { $0.id == .arrivalTime }?.titleHint)
        XCTAssertNotNil(arrivalTime(makeViewModel(relayed: false, network: .ethereum, estimatedDurationSeconds: .max)))
    }

    func testADirectWithdrawalWithoutAnEstimateShowsNoArrivalTime() {
        let viewModel = makeViewModel(relayed: false, network: .ethereum, estimatedDurationSeconds: nil)

        XCTAssertNil(arrivalTime(viewModel))
    }

    func testRelayedWithdrawalsOnlyShowTheBackendEstimateIncludingBitcoin() {
        for network in [PerpsFundingNetwork.ton, .bitcoin, .arbitrum] {
            XCTAssertNil(arrivalTime(makeViewModel(relayed: true, network: network, estimatedDurationSeconds: nil)))
            XCTAssertEqual(
                arrivalTime(makeViewModel(relayed: true, network: network, estimatedDurationSeconds: 181)),
                TKLocales.Ramp.Deposit.upToMin(4)
            )
        }
    }

    func testRelayedWithdrawalUsesTheTotalFeeTitleAndUnknownCostStaysUnavailable() throws {
        let viewModel = makeViewModel(relayed: true, network: .arbitrum, estimatedDurationSeconds: nil, networkFee: nil)
        let fee = try XCTUnwrap(viewModel.rows.first { $0.id == .networkFee })
        XCTAssertEqual(fee.title, TKLocales.Perps.Confirm.fee)
        XCTAssertEqual(fee.value, PerpsFundingText.missing)
    }

    func testDirectWithdrawalKeepsTheNetworkFeeTitle() {
        let viewModel = makeViewModel(relayed: false, network: .ethereum, estimatedDurationSeconds: nil)
        XCTAssertEqual(viewModel.rows.first { $0.id == .networkFee }?.title, TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee)
    }

    func testTheRecipientAndTheProviderAreShownBetweenWhatIsReceivedAndTheFee() throws {
        let viewModel = makeViewModel(
            relayed: true,
            network: .bsc,
            estimatedDurationSeconds: 60,
            recipientAddress: "0x0eE3...508b",
            provider: "Relay"
        )

        XCTAssertEqual(viewModel.rows.map(\.id), [.youWithdraw, .youReceive, .recipientAddress, .provider, .networkFee, .arrivalTime])
        let recipient = try XCTUnwrap(viewModel.rows.first { $0.id == .recipientAddress })
        XCTAssertEqual(recipient.title, TKLocales.ConfirmSend.Recipient.address)
        XCTAssertEqual(recipient.value, "0x0eE3...508b")
        let provider = try XCTUnwrap(viewModel.rows.first { $0.id == .provider })
        XCTAssertEqual(provider.title, TKLocales.NativeSwap.Screen.Confirm.Field.provider)
        XCTAssertEqual(provider.value, "Relay")
    }

    func testTermsWithoutARecipientOrProviderShowNeither() {
        let viewModel = makeViewModel(relayed: true, network: .bsc, estimatedDurationSeconds: nil)

        XCTAssertEqual(viewModel.rows.map(\.id), [.youWithdraw, .youReceive, .networkFee])
    }

    func testFeesFromFifteenPercentOfTheAmountAreWarnedAbout() {
        XCTAssertNil(PerpsFundingConfirmRows.highFeeNotice(fee: 1.49, of: 10))
        XCTAssertEqual(PerpsFundingConfirmRows.highFeeNotice(fee: 1.5, of: 10), TKLocales.Perps.Funding.highFee(15))
        XCTAssertNil(PerpsFundingConfirmRows.highFeeNotice(fee: 1, of: 0))

        let costly = makeViewModel(relayed: true, network: .bitcoin, estimatedDurationSeconds: nil, networkFeeUsd: 2.3)
        XCTAssertEqual(costly.noticeText, TKLocales.Perps.Funding.highFee(23))
        XCTAssertTrue(costly.isNoticeWarning)
        XCTAssertNil(makeViewModel(relayed: true, network: .bitcoin, estimatedDurationSeconds: nil, networkFeeUsd: 0.9).noticeText)
    }

    /// A moved Lighter fee is refused before signing, so the same amount is quoted again and shown.
    func testAWithdrawalRefusedForItsQuoteIsRequotedForTheSameAmount() async {
        var requoted = 0
        let viewModel = makeViewModel(
            relayed: true,
            network: .tron,
            estimatedDurationSeconds: nil,
            pay: { _ in throw CancellationError() },
            message: { _ in .quoteExpired },
            requote: {
                requoted += 1
                return Self.reviewed(withdrawAmount: "9.5")
            }
        )

        viewModel.confirm()
        await waitUntil(viewModel) { viewModel.rows.first { $0.id == .youWithdraw }?.value == PerpsFormatting.test.usd("9.5") }

        XCTAssertEqual(requoted, 1)
        XCTAssertEqual(viewModel.errorText, PerpsWithdrawErrorText.text(for: .quoteExpired))
        XCTAssertTrue(viewModel.isConfirmationEnabled)
    }

    func testAWithdrawalRateLimitShowsItsMessageWithoutRequotingOrCompleting() async {
        var requoted = false
        var completed = false
        let viewModel = makeViewModel(
            relayed: true,
            network: .ton,
            estimatedDurationSeconds: nil,
            pay: { _ in throw CancellationError() },
            message: { _ in .withdrawalRateLimited },
            requote: {
                requoted = true
                return Self.reviewed()
            }
        )
        viewModel.onPaid = { _ in completed = true }

        viewModel.confirm()
        await waitUntil(viewModel) { viewModel.errorText != nil }

        XCTAssertEqual(viewModel.errorText, TKLocales.Perps.WithdrawForm.rateLimited)
        XCTAssertFalse(requoted)
        XCTAssertFalse(completed)
        XCTAssertTrue(viewModel.isConfirmationEnabled)
    }

    func testALapsedQuoteIsStillPaidForTheServiceToRenewAfterThePasscode() async {
        let paid = expectation(description: "paid")
        var requoted = false
        let viewModel = makeViewModel(
            relayed: true,
            network: .tron,
            estimatedDurationSeconds: nil,
            expiresAt: Date(timeIntervalSinceNow: -60),
            requote: {
                requoted = true
                return Self.reviewed()
            }
        )
        viewModel.onPaid = { _ in paid.fulfill() }

        viewModel.confirm()
        await fulfillment(of: [paid], timeout: 2)

        XCTAssertFalse(requoted)
        XCTAssertNil(viewModel.errorText)
    }

    func testARequoteHoldsConfirmationWithoutShowingAPayment() async {
        var requoting = false
        let requoteEntered = TestSignal()
        var release: AsyncStream<Void>.Continuation?
        let gate = AsyncStream<Void> { release = $0 }
        let viewModel = makeViewModel(
            relayed: true,
            network: .tron,
            estimatedDurationSeconds: nil,
            pay: { _ in throw CancellationError() },
            message: { _ in .quoteExpired },
            requote: {
                requoting = true
                requoteEntered.send()
                for await _ in gate {
                    break
                }
                return Self.reviewed(withdrawAmount: "9.5")
            }
        )

        viewModel.confirm()
        await waitUntil(requoteEntered) { requoting }

        XCTAssertFalse(viewModel.isConfirmationEnabled)
        XCTAssertFalse(viewModel.isProcessing)

        release?.yield()
        await waitUntil(viewModel) { viewModel.isConfirmationEnabled }
    }

    private func arrivalTime(_ viewModel: PerpsWithdrawConfirmViewModel) -> String? {
        viewModel.rows.first { $0.id == .arrivalTime }?.value
    }

    private func makeViewModel(
        relayed: Bool,
        network: PerpsFundingNetwork,
        estimatedDurationSeconds: Int?,
        networkFee: String? = "0",
        networkFeeUsd: Decimal? = nil,
        expiresAt: Date? = nil,
        recipientAddress: String? = nil,
        provider: String? = nil,
        pay: @escaping @Sendable (String) async throws -> String = { _ in "op" },
        message: @escaping (Error) -> PerpsWithdrawMessage = { _ in .failed },
        requote: (() async throws -> PerpsReviewedWithdraw)? = nil
    ) -> PerpsWithdrawConfirmViewModel {
        PerpsWithdrawConfirmViewModel(
            reviewed: Self.reviewed(
                relayed: relayed,
                estimatedDurationSeconds: estimatedDurationSeconds,
                networkFee: networkFee,
                networkFeeUsd: networkFeeUsd,
                expiresAt: expiresAt,
                recipientAddress: recipientAddress,
                provider: provider,
                pay: pay
            ),
            destination: PerpsDepositSource(assetId: "asset", symbol: "USDC", decimals: 6, network: network),
            balance: nil,
            format: .test,
            message: message,
            passcodeProvider: { "0000" },
            requote: requote
        )
    }

    private nonisolated static func reviewed(
        withdrawAmount: String = "10",
        relayed: Bool = true,
        estimatedDurationSeconds: Int? = nil,
        networkFee: String? = "0",
        networkFeeUsd: Decimal? = nil,
        expiresAt: Date? = nil,
        recipientAddress: String? = nil,
        provider: String? = nil,
        pay: @escaping @Sendable (String) async throws -> String = { _ in "op" }
    ) -> PerpsReviewedWithdraw {
        PerpsReviewedWithdraw(
            terms: PerpsWithdrawTerms(
                requestedAmount: withdrawAmount,
                withdrawAmount: withdrawAmount,
                receiveAmount: withdrawAmount,
                receivesAtLeast: relayed,
                receiveSymbol: "USDC",
                networkFee: networkFee,
                networkFeeSymbol: "USDC",
                networkFeeUsd: networkFeeUsd,
                expiresAt: expiresAt,
                estimatedDurationSeconds: estimatedDurationSeconds,
                recipientAddress: recipientAddress,
                provider: provider
            ),
            pay: pay
        )
    }
}
