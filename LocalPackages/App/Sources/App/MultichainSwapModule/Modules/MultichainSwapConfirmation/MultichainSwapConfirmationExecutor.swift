import KeeperCore
import OperationReviewModels

struct MultichainSwapConfirmationExecutor {
    let executionService: MultichainSwapExecutionService

    func execute(
        signer: MultichainTransferSigner,
        swapWallet: MultichainSwapWallet,
        input: MultichainSwapConfirmationInput,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod,
        consent: OperationConsent
    ) async -> Result<MultichainSwapExecutionResult, MultichainSwapExecutionFailure> {
        do {
            return try .success(
                await executionService.execute(
                    signer: signer,
                    swapWallet: swapWallet,
                    sourceAsset: input.userInput.sendAsset,
                    destinationAsset: input.userInput.receiveAsset,
                    executionPlan: executionPlan,
                    feeMethod: feeMethod,
                    spendLimit: input.spendLimit,
                    consent: consent
                )
            )
        } catch {
            return .failure(error)
        }
    }
}
