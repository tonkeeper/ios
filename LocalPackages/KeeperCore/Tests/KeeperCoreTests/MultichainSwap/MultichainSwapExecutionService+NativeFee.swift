@testable import KeeperCore

extension MultichainSwapExecutionService {
    /// Production always states the method it is paying with. Tests that are not about the fee method
    /// say `native` once, here, rather than at every call.
    func execute(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        approvalMode: MultichainSwapApprovalMode = .exact
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        try await execute(
            passcodeProvider: passcodeProvider,
            wallet: wallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            executionPlan: executionPlan,
            approvalMode: approvalMode,
            feeMethod: .native
        )
    }
}
