import BigInt
@testable import KeeperCore
import OperationReviewModels

extension MultichainSwapExecutionService {
    /// Production always states the method it is paying with, who signs, what the user agreed to
    /// spend and how they answer a review. Tests that are not about those say `native` once, here,
    /// rather than at every call, sign with a mnemonic, and refuse whatever a review asks about.
    func execute(
        passcodeProvider: @escaping () async -> String?,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod = .native,
        spendLimit: BigUInt = 0,
        consent: OperationConsent = .refuse
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        try await execute(
            signer: .mnemonic(passcodeProvider: passcodeProvider),
            swapWallet: swapWallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            executionPlan: executionPlan,
            feeMethod: feeMethod,
            spendLimit: spendLimit,
            consent: consent
        )
    }
}
