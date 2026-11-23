import KeeperCore
import OperationReviewModels

@MainActor
struct TransactionConfirmRun {
    let confirmationController: TransactionConfirmationController
    let fundsValidator: InsufficientFundsValidator
    let pendingTransactionsService: PendingTransactionsService
    let confirmSendAll: @MainActor (_ tokenName: String) async -> Bool
    let enterProcessing: @MainActor () -> Void
    /// This swipe's answers, from the preview it asks about down to the gate before the signature.
    let consent: OperationConsent

    func run(model: TransactionConfirmationModel) async -> ConfirmActionResult {
        if model.isMaxAmountUsed {
            let confirmed = await confirmSendAll(model.amount?.token.symbol ?? "Token")
            guard !Task.isCancelled else {
                return .cancelledByUser
            }
            guard confirmed else {
                return .cancelledByUser
            }
        }

        if let review = model.review, review.requiresConsent {
            let consented = await consent(review)
            guard !Task.isCancelled, consented else {
                return .cancelledByUser
            }
        }

        enterProcessing()

        do {
            try await fundsValidator.validateFundsIfNeeded(wallet: model.wallet, emulationModel: model)
        } catch {
            return .insufficientFunds(error)
        }
        guard !Task.isCancelled else {
            return .cancelledByUser
        }

        let result = await confirmationController.sendTransaction(consent: consent)
        if case let .success(sendResult) = result {
            await pendingTransactionsService.record(
                sendResult,
                wallet: confirmationController.getModel().wallet
            )
        }
        guard !Task.isCancelled else {
            return .cancelledByUser
        }

        switch result {
        case .success:
            return .success
        case let .failure(error):
            if case .cancelledByUser = error {
                return .cancelledByUser
            }
            if case let .multichainTransactionFailure(failure) = error {
                switch failure {
                case .feeQuoteLoading:
                    return .feeQuoteLoading
                // A payment the node refused for want of funds was signed at the price shown before the
                // swipe: signed again as it is, it would be refused again.
                case .batteryMigrationFailed, .relayerQuoteUnavailable, .operationExpired, .failedToSendSigned(.insufficientBalance, _):
                    return .requote(error)
                default:
                    break
                }
            }
            return .failure(error)
        }
    }
}

extension TransactionConfirmRun {
    enum ConfirmActionResult {
        case cancelledByUser
        case feeQuoteLoading
        case insufficientFunds(InsufficientFundsError)
        case failure(TransactionConfirmationError)
        /// The prepared operation or its fee is stale: refresh before the next swipe.
        case requote(TransactionConfirmationError)
        case success
    }
}
