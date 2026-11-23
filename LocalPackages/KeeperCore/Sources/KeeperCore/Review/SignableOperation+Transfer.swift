import ChainKit

extension SignableOperation {
    /// The wallet's own send of `amount` of the account's asset to `recipient`, as chain-kit reads it:
    /// its `main` payload, which chain-kit signs as it is or the SDK signs the transfer it is built
    /// from. Its ids never change, so the same send built again is the same review.
    static func transfer(
        from account: ChainKit.Account,
        to recipient: String,
        amount: BignumBigInteger,
        memo: String?,
        isMax: Bool,
        intent: OperationIntent,
        fidelity: Fidelity,
        client: CryptoKitClient
    ) async throws -> SignableOperation {
        guard let to = Address.Companion.shared.from(value: recipient, chain: account.chain, type: .default_) else {
            throw ChainKitOperationError.malformed("\(account.chain.name) recipient")
        }
        let result = try await client.blockchain.getMediator(network: account.chain.network.type).operation.transfer(
            account: account,
            to: to,
            amount: amount,
            memo: memo,
            isMax: isMax
        )
        guard let meta = result.getOrNull() else {
            throw ChainKitOperationError.malformed(result.error?.message ?? "unknown")
        }
        let payload = ChainKit.Payload(
            id: "main",
            type: .main,
            chain: account.chain,
            version: ChainKit.Payload.Companion.shared.VERSION,
            fee: nil,
            meta: meta
        )
        return SignableOperation(
            // A `main` meta chain-kit typed itself is written with no JSON to read, so `build` cannot fail on it.
            operation: ChainKit.Operation.Companion.shared.build(id: "transfer", payloads: [payload]),
            account: account,
            intent: intent,
            fidelity: fidelity
        )
    }
}
