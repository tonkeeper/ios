import ChainKit

/// Signs and encodes a swap transaction with the per-chain ChainKit delegate.
/// Bitcoin signs with the whole wallet (the delegate needs the UTXO set); every
/// other chain signs with the chain's private key.
struct SwapTransactionSigner {
    func signAndEncode<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        wallet: CryptoWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> KotlinByteArray {
        let signingOutputs = try await withCheckedContinuation { (continuation: CheckedContinuation<Result<SigSet<KotlinByteArray>, MultichainSwapExecutionFailure>, Never>) in
            let handler: @Sendable (SignRes<SigSet<KotlinByteArray>>?, Error?) -> Void = { result, error in
                if let error {
                    return continuation.resume(
                        returning: .failure(
                            .signingFailed(
                                payloadId: payloadId,
                                kind: .unknown,
                                reason: "chain kit failed to sign swap payload due to error: \(error.logDescription)"
                            )
                        )
                    )
                }
                guard let value = result?.getOrNull() else {
                    let chainKitError = result.flatMap(\.error)
                    let error = chainKitError.map(\.logValue) ?? "unknown"
                    return continuation.resume(
                        returning: .failure(
                            .signingFailed(
                                payloadId: payloadId,
                                kind: ChainKitErrorKindClassifier.kind(signError: chainKitError),
                                reason: "chain kit failed to sign swap payload due to error: \(error)"
                            )
                        )
                    )
                }
                continuation.resume(returning: .success(value))
            }

            switch sourceChain {
            case .btc:
                mediator.sign.transaction.signAndEncode(
                    transaction: transaction,
                    fee: fee,
                    nonce: nonce,
                    wallet: wallet,
                    completionHandler: handler
                )
            case .ton, .eth, .base, .tron, .arb, .bsc:
                mediator.sign.transaction.signAndEncode(
                    transaction: transaction,
                    fee: fee,
                    nonce: nonce,
                    privateKey: wallet.getPrivateKey(
                        chain: sourceChain.asChainKitChain
                    ),
                    completionHandler: handler
                )
            }
        }.get()

        guard let output = signingOutputs.outputs.compactMap({ $0 as? KotlinByteArray }).first else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "empty or nil swap signing outputs"
            )
        }
        return output
    }
}
