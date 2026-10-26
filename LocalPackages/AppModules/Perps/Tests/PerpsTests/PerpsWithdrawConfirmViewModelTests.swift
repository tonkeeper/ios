@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsWithdrawConfirmViewModelTests: XCTestCase {
    func testADirectWithdrawalShowsTheVenueDelayRoundedUpToMinutes() {
        let viewModel = makeViewModel(relayed: false, network: .ethereum, withdrawalDelaySeconds: 1072)

        XCTAssertEqual(arrivalTime(viewModel), TKLocales.Ramp.Deposit.upToMin(18))
        XCTAssertNotNil(arrivalTime(makeViewModel(relayed: false, network: .ethereum, withdrawalDelaySeconds: .max)))
    }

    func testADirectWithdrawalWithoutTheVenueDelayShowsNoArrivalTime() {
        let viewModel = makeViewModel(relayed: false, network: .ethereum, withdrawalDelaySeconds: nil)

        XCTAssertNil(arrivalTime(viewModel))
    }

    func testARelayedWithdrawalShowsTwoMinutesExceptToBitcoin() {
        XCTAssertEqual(
            arrivalTime(makeViewModel(relayed: true, network: .ton, withdrawalDelaySeconds: nil)),
            TKLocales.Ramp.Deposit.upToMin(2)
        )
        XCTAssertNil(arrivalTime(makeViewModel(relayed: true, network: .bitcoin, withdrawalDelaySeconds: nil)))
    }

    func testRelayedWithdrawalUsesTheTotalFeeTitleAndUnknownCostStaysUnavailable() throws {
        let viewModel = makeViewModel(relayed: true, network: .arbitrum, withdrawalDelaySeconds: nil, networkFee: nil)
        let fee = try XCTUnwrap(viewModel.rows.first { $0.id == .networkFee })
        XCTAssertEqual(fee.title, TKLocales.Perps.Confirm.fee)
        XCTAssertEqual(fee.value, PerpsFundingText.missing)
    }

    func testDirectWithdrawalKeepsTheNetworkFeeTitle() {
        let viewModel = makeViewModel(relayed: false, network: .ethereum, withdrawalDelaySeconds: nil)
        XCTAssertEqual(viewModel.rows.first { $0.id == .networkFee }?.title, TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee)
    }

    func testFeesFromFifteenPercentOfTheAmountAreWarnedAbout() {
        XCTAssertNil(PerpsFundingConfirmRows.highFeeNotice(fee: 1.49, of: 10))
        XCTAssertEqual(PerpsFundingConfirmRows.highFeeNotice(fee: 1.5, of: 10), TKLocales.Perps.Funding.highFee(15))
        XCTAssertNil(PerpsFundingConfirmRows.highFeeNotice(fee: 1, of: 0))

        let costly = makeViewModel(relayed: true, network: .bitcoin, withdrawalDelaySeconds: nil, networkFeeUsd: 2.3)
        XCTAssertEqual(costly.noticeText, TKLocales.Perps.Funding.highFee(23))
        XCTAssertTrue(costly.isNoticeWarning)
        XCTAssertNil(makeViewModel(relayed: true, network: .bitcoin, withdrawalDelaySeconds: nil, networkFeeUsd: 0.9).noticeText)
    }

    /// A moved Lighter fee is refused before signing, so the same amount is quoted again and shown.
    func testAWithdrawalRefusedForItsQuoteIsRequotedForTheSameAmount() async {
        var requoted = 0
        let viewModel = makeViewModel(
            relayed: true,
            network: .tron,
            withdrawalDelaySeconds: nil,
            pay: { _ in throw CancellationError() },
            message: { _ in .quoteExpired },
            requote: {
                requoted += 1
                return Self.reviewed(withdrawAmount: "9.5")
            }
        )

        viewModel.confirm()
        await waitUntil { viewModel.rows.first { $0.id == .youWithdraw }?.value == PerpsFormatting.test.usd("9.5") }

        XCTAssertEqual(requoted, 1)
        XCTAssertEqual(viewModel.errorText, PerpsWithdrawErrorText.text(for: .quoteExpired))
        XCTAssertTrue(viewModel.isConfirmationEnabled)
    }

    func testARequoteHoldsConfirmationWithoutShowingAPayment() async {
        var requoting = false
        var release: AsyncStream<Void>.Continuation?
        let gate = AsyncStream<Void> { release = $0 }
        let viewModel = makeViewModel(
            relayed: true,
            network: .tron,
            withdrawalDelaySeconds: nil,
            pay: { _ in throw CancellationError() },
            message: { _ in .quoteExpired },
            requote: {
                requoting = true
                for await _ in gate {
                    break
                }
                return Self.reviewed(withdrawAmount: "9.5")
            }
        )

        viewModel.confirm()
        await waitUntil { requoting }

        XCTAssertFalse(viewModel.isConfirmationEnabled)
        XCTAssertFalse(viewModel.isProcessing)

        release?.yield()
        await waitUntil { viewModel.isConfirmationEnabled }
    }

    private func arrivalTime(_ viewModel: PerpsWithdrawConfirmViewModel) -> String? {
        viewModel.rows.first { $0.id == .arrivalTime }?.value
    }

    private func makeViewModel(
        relayed: Bool,
        network: PerpsFundingNetwork,
        withdrawalDelaySeconds: Int?,
        networkFee: String? = "0",
        networkFeeUsd: Decimal? = nil,
        pay: @escaping @Sendable (String) async throws -> String = { _ in "op" },
        message: @escaping (Error) -> PerpsWithdrawMessage = { _ in .failed },
        requote: (() async throws -> PerpsReviewedWithdraw)? = nil
    ) -> PerpsWithdrawConfirmViewModel {
        PerpsWithdrawConfirmViewModel(
            reviewed: Self.reviewed(
                relayed: relayed,
                withdrawalDelaySeconds: withdrawalDelaySeconds,
                networkFee: networkFee,
                networkFeeUsd: networkFeeUsd,
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
        withdrawalDelaySeconds: Int? = nil,
        networkFee: String? = "0",
        networkFeeUsd: Decimal? = nil,
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
                withdrawalDelaySeconds: withdrawalDelaySeconds
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
