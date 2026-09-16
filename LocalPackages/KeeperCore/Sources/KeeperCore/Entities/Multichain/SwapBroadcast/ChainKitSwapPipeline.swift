import ChainKit

protocol ChainKitSwapPipeline {
    func prepareSwapPayloads(
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        provider: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPipelinePreparation

    func executeSwapPayloads(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees: MultichainSwapPayloadFees,
        provider: MultichainSwapProvider,
        approvalMode: MultichainSwapApprovalMode
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult
}
