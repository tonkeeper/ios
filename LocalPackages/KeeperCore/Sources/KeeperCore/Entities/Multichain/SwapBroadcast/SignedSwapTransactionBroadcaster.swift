import ChainKit

/// Broadcasts a signed swap transaction to the network through the ChainKit
/// mediator and returns its transaction hash.
struct SignedSwapTransactionBroadcaster {
    func broadcast<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        account: ChainKit.Account,
        signingOutput: KotlinByteArray,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> String {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, MultichainSwapExecutionFailure>, Never>) in
            mediator.transaction.sendEncodedTransaction(
                account: account,
                signingOutput: signingOutput
            ) { result, error in
                if let error {
                    return continuation.resume(
                        returning: .failure(
                            .broadcastFailed(
                                payloadId: payloadId,
                                kind: .unknown,
                                reason: "chain kit failed to send encoded swap transaction due to error: \(error.logDescription)"
                            )
                        )
                    )
                }
                guard let value = result?.getOrNull() else {
                    let chainKitError = result.flatMap(\.error)
                    let error = chainKitError.map(\.logValue) ?? "unknown"
                    return continuation.resume(
                        returning: .failure(
                            .broadcastFailed(
                                payloadId: payloadId,
                                kind: ChainKitErrorKindClassifier.kind(nodeError: chainKitError),
                                reason: "chain kit failed to send encoded swap transaction due to error: \(error)"
                            )
                        )
                    )
                }
                continuation.resume(returning: .success(value as String))
            }
        }.get()
    }
}
