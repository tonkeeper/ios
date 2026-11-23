import ChainKit

/// Resolves the next account nonce for a swap route. The nonce anchors the payload
/// ordering: an ERC20 approve is broadcast at nonce N and the main swap at N+1.
struct SwapNonceProvider {
    func nonce<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        account: ChainKit.Account,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> BignumBigInteger {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<BignumBigInteger, MultichainSwapExecutionFailure>, Never>) in
            mediator.account.estimateNonce(account: account) { result, error in
                if let error {
                    return continuation.resume(
                        returning: .failure(
                            .nonceFailed(
                                payloadId: payloadId,
                                kind: .unknown,
                                reason: "chain kit failed to estimate nonce due to error: \(error.logDescription)"
                            )
                        )
                    )
                }
                guard let value = result?.getOrNull() else {
                    let chainKitError = result.flatMap(\.error)
                    let error = chainKitError.map(\.logValue) ?? "unknown"
                    return continuation.resume(
                        returning: .failure(
                            .nonceFailed(
                                payloadId: payloadId,
                                kind: ChainKitErrorKindClassifier.kind(nodeError: chainKitError),
                                reason: "chain kit failed to estimate nonce due to error: \(error)"
                            )
                        )
                    )
                }
                continuation.resume(returning: .success(value))
            }
        }.get()
    }

    /// Waits for the account's nonce to reach `expected`: a TON wallet accepts the transaction at a seqno only
    /// once the one before it has landed.
    func waitForNonce<I, O>(
        _ expected: BignumBigInteger,
        mediator: ChainMediatorWrapper<I, O>,
        account: ChainKit.Account,
        payloadId: String,
        timeout: TimeInterval = 120
    ) async throws(MultichainSwapExecutionFailure) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let current = try? await nonce(mediator: mediator, account: account, payloadId: payloadId),
               current.compareTo(other: expected) >= 0
            {
                return
            }
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                throw .canceled
            }
        }
        throw .broadcastFailed(
            payloadId: payloadId,
            kind: .networkError,
            reason: "the account nonce did not reach \(expected) in \(Int(timeout)) s"
        )
    }
}
