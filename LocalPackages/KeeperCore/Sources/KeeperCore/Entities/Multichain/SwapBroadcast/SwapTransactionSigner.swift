import ChainKit

/// Signs and encodes a swap transaction with the per-chain ChainKit delegate.
/// Bitcoin signs with the whole HD wallet (the delegate needs the UTXO set); every
/// other chain signs with the chain's private key.
struct SwapTransactionSigner {
    private let tonBatchSigner = TonSwapBatchSigner()

    func signAndEncode<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transactions: [any ChainKit.Transaction],
        fee: Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        wallet: SwapSigningWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> KotlinByteArray {
        guard transactions.count > 1 else {
            guard let transaction = transactions.first else {
                throw .signingFailed(
                    payloadId: payloadId,
                    kind: .missingField,
                    reason: "swap payload has no transaction to sign"
                )
            }
            return try await signAndEncode(
                mediator: mediator,
                transaction: transaction,
                fee: fee,
                nonce: nonce,
                sourceChain: sourceChain,
                wallet: wallet,
                payloadId: payloadId
            )
        }
        guard sourceChain == .ton else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unsupportedTransaction,
                reason: "\(sourceChain.rawValue) cannot sign several swap messages as one transaction"
            )
        }
        return try await tonBatchSigner.signAndEncode(
            mediator: mediator,
            batch: transactions,
            fee: fee,
            nonce: nonce,
            privateKey: wallet.privateKey(chain: sourceChain),
            payloadId: payloadId
        )
    }

    private func signAndEncode<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        wallet: SwapSigningWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> KotlinByteArray {
        let signer = try resolvedSigner(wallet: wallet, sourceChain: sourceChain, payloadId: payloadId)
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

            switch signer {
            case let .wallet(wallet):
                mediator.sign.transaction.signAndEncode(
                    transaction: transaction,
                    fee: fee,
                    nonce: nonce,
                    wallet: wallet,
                    completionHandler: handler
                )
            case let .privateKey(privateKey):
                mediator.sign.transaction.signAndEncode(
                    transaction: transaction,
                    fee: fee,
                    nonce: nonce,
                    privateKey: privateKey,
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

private extension SwapTransactionSigner {
    enum Signer {
        case wallet(CryptoWallet)
        case privateKey(ChainKit.PrivateKey)
    }

    func resolvedSigner(
        wallet: SwapSigningWallet,
        sourceChain: MultichainChain,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) -> Signer {
        switch (sourceChain, wallet) {
        case let (.btc, .hd(wallet)):
            return .wallet(wallet)
        case (.btc, .legacy):
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "a legacy wallet cannot sign a bitcoin payload"
            )
        case (.ton, _), (.eth, _), (.base, _), (.tron, _), (.arb, _), (.bsc, _), (.sol, _), (.polygon, _), (.avax, _), (.robinhood, _):
            return try .privateKey(wallet.privateKey(chain: sourceChain))
        }
    }
}
