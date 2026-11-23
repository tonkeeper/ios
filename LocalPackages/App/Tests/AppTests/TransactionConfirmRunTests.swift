@testable import App
import BigInt
@testable import KeeperCore
import OperationReviewModels
import TonSwift
import XCTest

/// What a confirmed swipe of the transfer screen sets off, step by step, and what each way it can
/// end reads as.
@MainActor
final class TransactionConfirmRunTests: XCTestCase {
    func testLoadingFeeWaitsWithoutAUserCancellationOrErrorOutcome() async {
        let steps = ConfirmSteps()
        let result = await makeRun(
            steps,
            sendResult: .failure(.multichainTransactionFailure(.feeQuoteLoading))
        ).run(model: model())

        guard case .feeQuoteLoading = result else { return XCTFail("Expected waiting for the existing fee refresh: \(result)") }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    func testUnavailableMethodAlreadyRefreshedByTheControllerDoesNotTriggerAnotherErrorRefresh() async {
        let steps = ConfirmSteps()
        let result = await makeRun(
            steps,
            sendResult: .failure(.multichainTransactionFailure(.feeMethodUnavailable))
        ).run(model: model())

        guard case .failure(.multichainTransactionFailure(.feeMethodUnavailable)) = result else {
            return XCTFail("Expected one failure without an automatic requote: \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    func test_aMaxSendAsksToSendAllAndADeclineGoesNoFurther() async {
        let steps = ConfirmSteps()

        let result = await makeRun(steps, sendsAll: false).run(model: model(isMax: true))

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.sendAllPrompt(tokenName: TonToken.ton.symbol)])
    }

    func test_aConfirmedMaxSendGoesOnToProcessing() async {
        let steps = ConfirmSteps()

        _ = await makeRun(steps).run(model: model(isMax: true))

        XCTAssertEqual(steps.recorded, [.sendAllPrompt(tokenName: TonToken.ton.symbol), .processing, .fundsCheck, .send])
    }

    func test_aMaxSendWithoutAnAmountAsksAboutTheToken() async {
        let steps = ConfirmSteps()

        _ = await makeRun(steps).run(model: model(isMax: true, amount: nil))

        XCTAssertEqual(steps.recorded.first, .sendAllPrompt(tokenName: "Token"))
    }

    func test_aSendBelowTheMaxProcessesBeforeTheFundsCheckAndSends() async {
        let steps = ConfirmSteps()

        let result = await makeRun(steps).run(model: model())

        guard case .success = result else {
            return XCTFail("expected a success, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    func test_aFundsShortageIsNotSent() async {
        let steps = ConfirmSteps()

        let result = await makeRun(steps, shortage: .unknownJetton).run(model: model())

        guard case .insufficientFunds(.unknownJetton) = result else {
            return XCTFail("expected a funds shortage, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck])
    }

    /// The swipe confirmed a model of a legacy wallet while the controller's current one is of a
    /// multichain wallet: only the latter has a feed the record reports to.
    func test_aSentTransferIsRecordedForTheControllersWallet() async {
        let steps = ConfirmSteps()

        let result = await makeRun(steps, controllerWallet: multichainWallet).run(model: model())

        guard case .success = result else {
            return XCTFail("expected a success, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send, .report(txHash: "0xsent")])
    }

    func test_aSendTheUserCancelledReadsAsCancelled() async {
        let result = await makeRun(ConfirmSteps(), sendResult: .failure(.cancelledByUser)).run(model: model())

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
    }

    func test_aFailedSendIsAFailureAndRecordsNothing() async {
        let steps = ConfirmSteps()

        let result = await makeRun(
            steps,
            controllerWallet: multichainWallet,
            sendResult: .failure(.failedToSign(message: "refused"))
        ).run(model: model())

        guard case .failure(.failedToSign(message: "refused")) = result else {
            return XCTFail("expected the send failure, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    /// The relayer would no longer take the fee confirmed: the screen quotes the transfer again, or
    /// every next swipe would meet the same refusal.
    func test_aFeeTheRelayerNoLongerHoldsIsQuotedAgain() async {
        let steps = ConfirmSteps()

        let result = await makeRun(
            steps,
            sendResult: .failure(.multichainTransactionFailure(.relayerQuoteUnavailable(reason: "priced again")))
        ).run(model: model())

        guard case .requote(.multichainTransactionFailure(.relayerQuoteUnavailable(reason: "priced again"))) = result else {
            return XCTFail("expected a new quote, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    func test_anOperationThatExpiredBeforeSigningIsPreparedAgain() async {
        let steps = ConfirmSteps()

        let result = await makeRun(
            steps,
            sendResult: .failure(.multichainTransactionFailure(.operationExpired))
        ).run(model: model())

        guard case .requote(.multichainTransactionFailure(.operationExpired)) = result else {
            return XCTFail("expected an expired operation to be quoted again, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    func testFailedBatteryMigrationRefreshesTheProvisionalFeePreview() async {
        let steps = ConfirmSteps()
        let result = await makeRun(
            steps,
            sendResult: .failure(.multichainTransactionFailure(.batteryMigrationFailed(reason: "offline")))
        ).run(model: model())

        guard case .requote(.multichainTransactionFailure(.batteryMigrationFailed)) = result else {
            return XCTFail("Expected a fresh fee preview: \(result)")
        }
    }

    /// A payment the node refused for want of funds was signed at the price shown before the swipe: the
    /// screen prices it again, or every next swipe would sign the same refused payment. A send the node
    /// did not take for another reason stays a failure.
    func test_aPaymentTheNodeRefusedForWantOfFundsIsPricedAgain() async {
        let refusals: [(MultichainSwapExecutionErrorKind, Bool)] = [(.insufficientBalance, true), (.networkError, false)]
        for (kind, requotes) in refusals {
            let steps = ConfirmSteps()
            let refused = MultichainTransactionFailure.failedToSendSigned(kind: kind, reason: "refused")

            let result = await makeRun(steps, sendResult: .failure(.multichainTransactionFailure(refused))).run(model: model())

            switch result {
            case let .requote(.multichainTransactionFailure(.failedToSendSigned(returned, _))) where requotes:
                XCTAssertEqual(returned, kind)
            case let .failure(.multichainTransactionFailure(.failedToSendSigned(returned, _))) where !requotes:
                XCTAssertEqual(returned, kind)
            default:
                XCTFail("expected \(refused.logDescription) to be \(requotes ? "priced again" : "a failure"), got \(result)")
            }
            XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
        }
    }

    /// Only that refusal is quoted again: an operation the relayer forgot, an outcome it did not
    /// report and a balance short of the fee stay failures.
    func test_otherRelayedFailuresAreNotQuotedAgain() async {
        let failures: [MultichainTransactionFailure] = [
            .relayerQuoteExpired,
            .relayerOutcomeUnknown(reason: "no answer"),
            .insufficientSelectedFee,
        ]
        for failure in failures {
            let result = await makeRun(ConfirmSteps(), sendResult: .failure(.multichainTransactionFailure(failure))).run(model: model())

            guard case let .failure(.multichainTransactionFailure(returned)) = result else {
                XCTFail("expected \(failure.logDescription) to stay a failure, got \(result)")
                continue
            }
            XCTAssertEqual(returned.logDescription, failure.logDescription)
        }
    }

    func test_aRunCancelledAtTheSendAllPromptGoesNoFurther() async {
        let steps = ConfirmSteps(cancellingTheRunAt: .sendAllPrompt(tokenName: TonToken.ton.symbol))

        let result = await runInItsOwnTask(makeRun(steps), model: model(isMax: true))

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.sendAllPrompt(tokenName: TonToken.ton.symbol)])
    }

    func test_aRunCancelledAtTheFundsCheckIsNotSent() async {
        let steps = ConfirmSteps(cancellingTheRunAt: .fundsCheck)

        let result = await runInItsOwnTask(makeRun(steps), model: model())

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck])
    }

    /// What the review of the preview found is asked about once the send-all prompt is answered, and
    /// before anything else: nothing is unlocked or sent for a transfer the user would not send.
    func test_aReviewThatNeedsConsentIsAskedAfterTheSendAllPromptAndBeforeProcessing() async {
        let steps = ConfirmSteps()

        let result = await makeRun(steps, consent: consent(steps, answering: true)).run(model: model(isMax: true, review: warning))

        guard case .success = result else {
            return XCTFail("expected a success, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.sendAllPrompt(tokenName: TonToken.ton.symbol), .consent, .processing, .fundsCheck, .send])
    }

    func test_aDeclinedReviewGoesNoFurther() async {
        let steps = ConfirmSteps()

        let result = await makeRun(steps, consent: consent(steps, answering: false)).run(model: model(review: warning))

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.consent])
    }

    func test_aReviewThatNeedsNoConsentIsNotAsked() async {
        let steps = ConfirmSteps()

        _ = await makeRun(steps, consent: consent(steps, answering: false)).run(model: model(review: info))

        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send])
    }

    /// The gate before the signature reads the review again: the answer of the swipe covers it, since
    /// the send is cleared with the same consent.
    func test_theSendIsClearedWithTheConsentTheSwipeGave() async {
        let steps = ConfirmSteps()

        _ = await makeRun(steps, consent: consent(steps, answering: true), clearedAtTheSend: warning).run(model: model(review: warning))

        XCTAssertEqual(steps.recorded, [.consent, .processing, .fundsCheck, .send])
    }

    func test_aRunCancelledWhileTheReviewIsAskedGoesNoFurther() async {
        let steps = ConfirmSteps(cancellingTheRunAt: .consent)

        let result = await runInItsOwnTask(makeRun(steps, consent: consent(steps, answering: true)), model: model(review: warning))

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.consent])
    }

    /// The transfer is out by then, so it is recorded before the cancellation is read.
    func test_aRunCancelledDuringTheSendIsRecordedAndReadsAsCancelled() async {
        let steps = ConfirmSteps(cancellingTheRunAt: .send)

        let result = await runInItsOwnTask(makeRun(steps, controllerWallet: multichainWallet), model: model())

        guard case .cancelledByUser = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertEqual(steps.recorded, [.processing, .fundsCheck, .send, .report(txHash: "0xsent")])
    }
}

private extension TransactionConfirmRunTests {
    var legacyWallet: Wallet {
        wallet(multichain: nil)
    }

    var multichainWallet: Wallet {
        wallet(multichain: .multichain(
            MultichainWalletState(
                walletId: "multichain-wallet-id",
                addresses: [MultichainWalletAddress(chain: .tron, address: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t")]
            )
        ))
    }

    func wallet(multichain: MultichainWallet?) -> Wallet {
        Wallet(
            id: "transaction-confirm-run-tests",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 0x01, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }

    var warning: OperationReview {
        OperationReview(id: "warning", findings: [OperationFinding(id: "finding", kind: "StubWarning", severity: .warning, title: "Finding")])
    }

    var info: OperationReview {
        OperationReview(id: "info", findings: [OperationFinding(id: "finding", kind: "StubInfo", severity: .info, title: "Finding")])
    }

    func model(
        isMax: Bool = false,
        amount: TransactionConfirmationModel.Amount? = .init(token: .ton(.ton), value: 1_000_000_000),
        wallet: Wallet? = nil,
        review: OperationReview? = nil
    ) -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: wallet ?? legacyWallet,
            recipient: nil,
            recipientAddress: nil,
            transaction: .transfer(.ton(isMax)),
            amount: amount,
            extraState: .none,
            availableExtraTypes: [],
            isMax: isMax,
            totalFee: 0,
            review: review
        )
    }

    /// A user who answers every review the same, each question a step of the run.
    func consent(_ steps: ConfirmSteps, answering answer: Bool) -> OperationConsent {
        OperationConsent { _ in
            await steps.record(.consent)
            return answer
        }
    }

    func makeRun(
        _ steps: ConfirmSteps,
        sendsAll: Bool = true,
        shortage: InsufficientFundsError? = nil,
        controllerWallet: Wallet? = nil,
        consent: OperationConsent = .refuse,
        clearedAtTheSend: OperationReview? = nil,
        sendResult: Result<TransactionConfirmationSendResult, TransactionConfirmationError> = .success(
            TransactionConfirmationSendResult(pendingTransactions: [
                MultichainPendingTransaction(
                    walletId: "multichain-wallet-id",
                    chain: .tron,
                    network: .mainnet,
                    txHash: "0xsent",
                    activityType: .send
                ),
            ])
        )
    ) -> TransactionConfirmRun {
        TransactionConfirmRun(
            confirmationController: ConfirmationControllerFake(
                model: model(wallet: controllerWallet),
                sendResult: sendResult,
                steps: steps,
                clearedAtTheSend: clearedAtTheSend
            ),
            fundsValidator: FundsValidatorFake(shortage: shortage, steps: steps),
            pendingTransactionsService: PendingTransactionsRecorder(steps: steps),
            confirmSendAll: { tokenName in
                steps.record(.sendAllPrompt(tokenName: tokenName))
                return sendsAll
            },
            enterProcessing: {
                steps.record(.processing)
            },
            consent: consent
        )
    }

    /// A run cancelled from inside must leave the test's own task alone.
    func runInItsOwnTask(
        _ run: TransactionConfirmRun,
        model: TransactionConfirmationModel
    ) async -> TransactionConfirmRun.ConfirmActionResult {
        await Task { await run.run(model: model) }.value
    }
}

/// Every step the run takes, in order, across the fakes; the one named at init cancels the run's task
/// when it is reached.
@MainActor
private final class ConfirmSteps {
    enum Step: Equatable {
        case sendAllPrompt(tokenName: String)
        case consent
        case processing
        case fundsCheck
        case send
        case report(txHash: String)
    }

    private(set) var recorded = [Step]()
    private let cancellingTheRunAt: Step?

    init(cancellingTheRunAt: Step? = nil) {
        self.cancellingTheRunAt = cancellingTheRunAt
    }

    func record(_ step: Step) {
        recorded.append(step)
        if step == cancellingTheRunAt {
            withUnsafeCurrentTask { $0?.cancel() }
        }
    }
}

private final class ConfirmationControllerFake: TransactionConfirmationController {
    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    private let model: TransactionConfirmationModel
    private let sendResult: Result<TransactionConfirmationSendResult, TransactionConfirmationError>
    private let steps: ConfirmSteps
    /// What a gate before the signature would clear with the consent the send is given.
    private let clearedAtTheSend: OperationReview?

    init(
        model: TransactionConfirmationModel,
        sendResult: Result<TransactionConfirmationSendResult, TransactionConfirmationError>,
        steps: ConfirmSteps,
        clearedAtTheSend: OperationReview?
    ) {
        self.model = model
        self.sendResult = sendResult
        self.steps = steps
        self.clearedAtTheSend = clearedAtTheSend
    }

    func getModel() -> TransactionConfirmationModel {
        model
    }

    func setLoading() {}

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        .success(())
    }

    /// As the gated controllers do: a send without the swipe's consent refuses what needs consent.
    func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        await sendTransaction(consent: .refuse)
    }

    func sendTransaction(consent: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        if let clearedAtTheSend, await !consent(clearedAtTheSend) {
            return .failure(.cancelledByUser)
        }
        await steps.record(.send)
        return sendResult
    }
}

private final class FundsValidatorFake: InsufficientFundsValidator {
    private let shortage: InsufficientFundsError?
    private let steps: ConfirmSteps

    init(shortage: InsufficientFundsError?, steps: ConfirmSteps) {
        self.shortage = shortage
        self.steps = steps
    }

    func resolveJettonBalance(
        jettonAddress _: Address,
        requiredAmount _: BigUInt,
        wallet _: Wallet
    ) async throws(InsufficientFundsError) -> JettonBalance {
        throw .unknownJetton
    }

    func validateFundsIfNeeded(
        wallet _: Wallet,
        confirmationController _: TransactionConfirmationController
    ) async throws(InsufficientFundsError) {}

    func validateFundsIfNeeded(
        wallet _: Wallet,
        emulationModel _: TransactionConfirmationModel
    ) async throws(InsufficientFundsError) {
        await steps.record(.fundsCheck)
        if let shortage {
            throw shortage
        }
    }

    func validateEmulationResultIfNeeded(
        _: SignRawEmulation,
        wallet _: Wallet,
        numOfInternals _: Int?
    ) throws(InsufficientFundsError) {}
}

private struct PendingTransactionsRecorder: PendingTransactionsService {
    let steps: ConfirmSteps

    func report(_ transaction: MultichainPendingTransaction) async {
        await steps.record(.report(txHash: transaction.txHash))
    }

    func flushRetained() async {}
}
