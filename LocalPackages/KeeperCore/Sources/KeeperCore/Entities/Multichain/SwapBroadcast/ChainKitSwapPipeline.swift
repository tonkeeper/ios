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
        signer: MultichainTransferSigner,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees: MultichainSwapPayloadFees,
        provider: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult
}
