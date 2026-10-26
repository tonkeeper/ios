import ChainKit
import Foundation
import WalletCore
import WalletCoreSwiftProtobuf

/// ChainKit signs one message per wallet transaction: it builds the signing input of every message,
/// the messages are packed into the first input, and WalletCore signs that.
struct TonSwapBatchSigner {
    func signAndEncode<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        batch: [any ChainKit.Transaction],
        fee: any Fee,
        nonce: BignumBigInteger,
        privateKey: ChainKit.PrivateKey,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> KotlinByteArray {
        guard let first = batch.first else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .missingField,
                reason: "ton batch has no message to sign"
            )
        }
        guard batch.allSatisfy({ $0.account == first.account }) else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unsupportedTransaction,
                reason: "ton batch is sent by more than one account"
            )
        }
        guard !batch.contains(where: \.isMax) else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unsupportedTransaction,
                reason: "ton batch cannot carry a max transfer"
            )
        }
        let firstInput = try await signingInput(
            mediator: mediator,
            transaction: first,
            fee: fee,
            nonce: nonce,
            privateKey: privateKey,
            payloadId: payloadId
        )
        try Self.requireCapacity(
            of: firstInput.walletVersion,
            messageCount: batch.count,
            payloadId: payloadId
        )
        var inputs = [firstInput]
        for transaction in batch.dropFirst() {
            try await inputs.append(
                signingInput(
                    mediator: mediator,
                    transaction: transaction,
                    fee: fee,
                    nonce: nonce,
                    privateKey: privateKey,
                    payloadId: payloadId
                )
            )
        }
        return try Self.signed(inputs, payloadId: payloadId)
    }

    static func requireCapacity(
        of walletVersion: TheOpenNetworkWalletVersion,
        messageCount: Int,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) {
        let capacity = walletVersion == .walletV5R1 ? 255 : 4
        guard messageCount <= capacity else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unsupportedTransaction,
                reason: "\(walletVersion) carries at most \(capacity) messages, got \(messageCount)"
            )
        }
    }

    static func signed(
        _ inputs: [TheOpenNetworkSigningInput],
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) -> KotlinByteArray {
        guard var input = inputs.first else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .missingField,
                reason: "ton batch has no message to sign"
            )
        }
        input.messages = inputs.flatMap(\.messages)
        let output: TheOpenNetworkSigningOutput = AnySigner.sign(input: input, coin: .ton)
        guard output.error == .ok else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .signInternalError,
                reason: "wallet core failed to sign the ton batch: \(output.errorMessage)"
            )
        }
        do {
            let encoded: Data = try output.serializedBytes()
            return encoded.asKotlinByteArray
        } catch {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .signInternalError,
                reason: "failed to encode the signed ton batch: \(error.localizedDescription)"
            )
        }
    }
}

private extension TonSwapBatchSigner {
    func signingInput<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        privateKey: ChainKit.PrivateKey,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> TheOpenNetworkSigningInput {
        let built: SignRes<SigSet<I>>
        do {
            built = try await mediator.sign.transaction.buildSigningInput(
                transaction: transaction,
                fee: fee,
                nonce: nonce,
                privateKey: privateKey
            )
        } catch {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "chain kit failed to build a ton batch message due to error: \(error.logDescription)"
            )
        }
        guard let input = built.getOrNull()?.firstOutput() else {
            let chainKitError = built.error
            throw .signingFailed(
                payloadId: payloadId,
                kind: ChainKitErrorKindClassifier.kind(signError: chainKitError),
                reason: "chain kit failed to build a ton batch message due to error: \(chainKitError.map(\.logValue) ?? "unknown")"
            )
        }
        do {
            return try TheOpenNetworkSigningInput(
                serializedBytes: mediator.sign.transaction.inputAdapter.encode(value: input).asData
            )
        } catch {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .signInternalError,
                reason: "chain kit built a ton batch message wallet core cannot read: \(error.localizedDescription)"
            )
        }
    }
}
