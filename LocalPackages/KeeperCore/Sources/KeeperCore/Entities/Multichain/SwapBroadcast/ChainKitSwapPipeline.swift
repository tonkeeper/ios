import ChainKit

protocol ChainKitSwapPipeline {
    func prepareSwapPayloads(
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        provider: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPipelinePreparation

    func executeSwapPayloads(
        passcodeProvider: @escaping () async -> String?,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees: MultichainSwapPayloadFees,
        provider: MultichainSwapProvider,
        approvalMode: MultichainSwapApprovalMode
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult
}
