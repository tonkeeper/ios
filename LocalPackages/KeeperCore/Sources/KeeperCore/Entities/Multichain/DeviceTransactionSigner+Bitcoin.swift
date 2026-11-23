import ChainKit
import Foundation
import TKLogging
import WalletCore
import WalletCoreSwiftProtobuf

extension DeviceTransactionSigner {
    /// ChainKit plans the spend without a key. The transaction the device signs is built here from the plan,
    /// so the PSBT and what goes on the wire are one transaction, and each signature has to verify against
    /// its input's BIP-143 digest before the spend is put together.
    static func signBitcoin<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        device: @Sendable (BitcoinDeviceSignRequest) async throws -> [Data]
    ) async throws(MultichainTransactionFailure) -> KotlinByteArray {
        guard let publicKey = transaction.account.publicKey,
              let receiveKey = Data(hexString: String(publicKey.defaultHex.dropFirst(2))),
              let accountXpub = BitcoinExtendedKey.converted(publicKey.segWit, to: BitcoinExtendedKey.xpubVersion)
        else {
            throw .failedToSign(kind: .signInternalError, reason: "the bitcoin account has no key to sign with")
        }
        let input: BitcoinSigningInput
        do {
            input = try await BitcoinSigningInput(serializedBytes: bitcoinSigningInput(mediator: mediator, transaction: transaction, fee: fee, nonce: nonce))
        } catch let failure as MultichainTransactionFailure {
            throw failure
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core cannot read the bitcoin signing input: \(error.localizedDescription)")
        }
        var previousTransactions: [Data: Data] = [:]
        for utxo in input.plan.utxos {
            previousTransactions[utxo.outPoint.hash] = await previousTransaction(utxo.outPoint.hash, mediator: mediator, account: transaction.account)
        }
        return try await signBitcoin(
            input: input,
            receiveKey: receiveKey,
            accountXpub: accountXpub,
            previousTransactions: previousTransactions,
            device: device
        ).asKotlinByteArray
    }

    /// The serialized `BitcoinSigningOutput` of `input`'s plan, spent from the address of `receiveKey`.
    static func signBitcoin(
        input: BitcoinSigningInput,
        receiveKey: Data,
        accountXpub: String,
        previousTransactions: [Data: Data],
        device: @Sendable (BitcoinDeviceSignRequest) async throws -> [Data]
    ) async throws(MultichainTransactionFailure) -> Data {
        let plan = input.plan
        let ownScript = BitcoinRawTransaction.witnessV0Script(publicKey: receiveKey)
        let destination = BitcoinScript.lockScriptForAddress(address: input.toAddress, coin: .bitcoin).data
        let change = BitcoinScript.lockScriptForAddress(address: input.changeAddress, coin: .bitcoin).data
        guard !plan.utxos.isEmpty, input.outputOpReturn.isEmpty, input.extraOutputs.isEmpty, input.lockTime == 0, input.hashType <= 1,
              plan.amount > 0, plan.change >= 0, !destination.isEmpty, plan.change == 0 || !change.isEmpty
        else {
            throw .failedToSign(kind: .signInternalError, reason: "a hardware wallet signs only plain bitcoin transfers")
        }
        guard plan.utxos.allSatisfy({ $0.script == ownScript && $0.amount > 0 }), plan.change == 0 || change == ownScript else {
            throw .failedToSign(kind: .signInternalError, reason: "a bitcoin input or the change is not the wallet's address")
        }
        let outputs = [BitcoinRawTransaction.Output(amount: UInt64(plan.amount), script: destination)]
            + (plan.change > 0 ? [BitcoinRawTransaction.Output(amount: UInt64(plan.change), script: change)] : [])
        let unsigned = BitcoinRawTransaction(
            version: 2,
            inputs: plan.utxos.map { BitcoinRawTransaction.Input(previousTxid: $0.outPoint.hash, previousIndex: $0.outPoint.index, script: Data(), sequence: 0xFFFF_FFFF, witness: []) },
            outputs: outputs,
            lockTime: 0
        )
        guard plan.utxos.reduce(0, { $0 + $1.amount }) - plan.amount - plan.change == plan.fee else {
            throw .failedToSign(kind: .signInternalError, reason: "the bitcoin plan does not add up to its fee")
        }
        let request = BitcoinDeviceSignRequest(
            accountXpub: accountXpub,
            publicKey: receiveKey,
            version: unsigned.version,
            lockTime: unsigned.lockTime,
            inputs: zip(plan.utxos, unsigned.inputs).map { utxo, input in
                BitcoinDeviceSignRequest.Input(
                    previousTxid: input.previousTxid,
                    previousIndex: input.previousIndex,
                    amount: UInt64(utxo.amount),
                    script: utxo.script,
                    previousTransaction: previousTransactions[input.previousTxid],
                    sequence: input.sequence
                )
            },
            outputs: outputs.enumerated().map { BitcoinDeviceSignRequest.Output(amount: $1.amount, script: $1.script, isChange: $0 > 0) }
        )
        let signatures = try await onDevice { try await device(request) }
        guard signatures.count == unsigned.inputs.count, let key = WalletCore.PublicKey(data: receiveKey, type: .secp256k1) else {
            throw .failedToSign(kind: .unknown, reason: "the device returned \(signatures.count) signatures for \(unsigned.inputs.count) inputs")
        }
        let digests = request.inputs.indices.map { unsigned.witnessV0Sighash(input: $0, amount: request.inputs[$0].amount, publicKey: receiveKey) }
        guard zip(signatures, digests).allSatisfy({ key.verifyAsDER(signature: $0, message: $1) }) else {
            throw .failedToSign(kind: .unknown, reason: "a device signature does not verify for its bitcoin input")
        }
        let signed = BitcoinRawTransaction(
            version: unsigned.version,
            inputs: zip(unsigned.inputs, signatures).map { input, signature in
                BitcoinRawTransaction.Input(
                    previousTxid: input.previousTxid,
                    previousIndex: input.previousIndex,
                    script: input.script,
                    sequence: input.sequence,
                    witness: [signature + [0x01], receiveKey]
                )
            },
            outputs: unsigned.outputs,
            lockTime: unsigned.lockTime
        )
        return try serialized(BitcoinSigningOutput.with { output in
            output.encoded = signed.serialized()
            output.transactionID = Data(signed.txid.reversed()).hexString
            output.transaction = BitcoinTransaction.with { transaction in
                transaction.version = Int32(signed.version)
                transaction.lockTime = signed.lockTime
                transaction.inputs = signed.inputs.map { input in
                    BitcoinTransactionInput.with {
                        $0.previousOutput = BitcoinOutPoint.with { outPoint in
                            outPoint.hash = input.previousTxid
                            outPoint.index = input.previousIndex
                            outPoint.sequence = input.sequence
                        }
                        $0.sequence = input.sequence
                    }
                }
                transaction.outputs = signed.outputs.map { output in
                    BitcoinTransactionOutput.with {
                        $0.value = Int64(output.amount)
                        $0.script = output.script
                    }
                }
            }
        })
    }
}

private extension DeviceTransactionSigner {
    static func bitcoinSigningInput<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger
    ) async throws(MultichainTransactionFailure) -> Data {
        let built: SignRes<SigSet<I>>
        do {
            built = try await mediator.sign.transaction.buildSigningInput(transaction: transaction, fee: fee, nonce: nonce, wallet: nil)
        } catch {
            throw .failedToSign(kind: .unknown, reason: "chain kit failed to plan the bitcoin transfer due to error: \(error.logDescription)")
        }
        guard let input = built.getOrNull()?.firstOutput() else {
            let chainKitError = built.error
            throw .failedToSign(
                kind: ChainKitErrorKindClassifier.kind(signError: chainKitError),
                reason: "chain kit failed to plan the bitcoin transfer due to error: \(chainKitError.map(\.logValue) ?? "unknown")"
            )
        }
        return mediator.sign.transaction.inputAdapter.encode(value: input).asData
    }

    /// The raw transaction `txid` names, when the node returns it and it hashes to that id.
    static func previousTransaction<I, O>(_ txid: Data, mediator: ChainMediatorWrapper<I, O>, account: ChainKit.Account) async -> Data? {
        let hash = Data(txid.reversed()).hexString
        do {
            let found = try await mediator.transaction.findTransaction(
                account: account,
                hash: hash,
                blockNumber: BignumBigInteger.Companion.shared.parseString(string: "0", base: 10)
            )
            guard let meta = found.getOrNull()?.meta, let raw = Data(hexString: meta), raw.count <= 50000,
                  BitcoinRawTransaction(parsing: raw)?.txid == txid
            else {
                Log.w("bitcoin input \(hash) is signed without its previous transaction")
                return nil
            }
            return raw
        } catch {
            Log.w("bitcoin input \(hash) is signed without its previous transaction", error: error)
            return nil
        }
    }
}
