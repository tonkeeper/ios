import KeeperCore

struct MultichainSwapConfirmationExecutor {
    let executionService: MultichainSwapExecutionService

    func execute(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        input: MultichainSwapConfirmationInput,
        executionPlan: MultichainSwapExecutionPlan,
        isUnlimitedApprovalEnabled: Bool,
        feeMethod: MultichainSwapFeeMethod
    ) async -> Result<MultichainSwapExecutionResult, MultichainSwapExecutionFailure> {
        do {
            return try .success(
                await executionService.execute(
                    passcodeProvider: passcodeProvider,
                    wallet: wallet,
                    sourceAsset: input.userInput.sendAsset,
                    destinationAsset: input.userInput.receiveAsset,
                    executionPlan: executionPlan,
                    approvalMode: isUnlimitedApprovalEnabled ? .unlimited : .exact,
                    feeMethod: feeMethod
                )
            )
        } catch {
            return .failure(error)
        }
    }
}
