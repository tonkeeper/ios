import ChainKit
import Foundation
import TronSwift
import WalletCore
import WalletCoreSwiftProtobuf

/// Signs a transfer on a hardware wallet. ChainKit builds the signing input without a key,
/// WalletCore turns it into what the device signs and, with the device's signature, into the
/// output ChainKit broadcasts. The signature must recover to the sender before anything goes out.
enum DeviceTransactionSigner {
    static func canSign(_ chain: MultichainChain) -> Bool {
        chain == .tron || chain == .sol || chain == .btc || chain.isEVM
    }

    static func signAndEncode<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        chain: MultichainChain,
        device: DeviceTransferSigner
    ) async throws(MultichainTransactionFailure) -> KotlinByteArray {
        if chain == .btc {
            return try await signBitcoin(mediator: mediator, transaction: transaction, fee: fee, nonce: nonce, device: device.bitcoin)
        }
        let input = try await signingInput(mediator: mediator, transaction: transaction, fee: fee, nonce: nonce)
        let sender = transaction.account.addressDisplay
        switch chain {
        case .tron:
            return try await signTron(input: input, sender: sender, device: device.tron).asKotlinByteArray
        case .sol:
            return try await signSolana(input: input, sender: sender, device: device.solana).asKotlinByteArray
        default:
            break
        }
        guard let chainId = chain.eip155ChainId else {
            throw .internal(reason: "a hardware wallet cannot sign a \(chain.rawValue) transfer")
        }
        return try await signEVM(input: input, chainId: chainId, sender: sender, device: device.evm).asKotlinByteArray
    }

    /// The serialized `EthereumSigningOutput` of `input` signed on the device.
    static func signEVM(
        input: Data,
        chainId: Int,
        sender: String,
        device: @Sendable (EVMDeviceSignRequest) async throws -> Data
    ) async throws(MultichainTransactionFailure) -> Data {
        let parsedInput: EthereumSigningInput
        do {
            parsedInput = try EthereumSigningInput(serializedBytes: input)
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core cannot read the evm signing input: \(error.localizedDescription)")
        }
        let unsigned = try preImage(coin: .ethereum, input: input)
        let signature = try await onDevice {
            try await device(EVMDeviceSignRequest(
                chainId: UInt64(chainId),
                transaction: unsigned.data,
                tokenContract: tokenContract(of: parsedInput)
            ))
        }
        try requireSender(sender, coin: .ethereum, signature: signature, digest: unsigned.dataHash)
        let output: EthereumSigningOutput = try compile(coin: .ethereum, input: input, signature: signature)
        guard output.error == .ok, !output.encoded.isEmpty else {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core failed to compile the evm transaction: \(output.errorMessage)")
        }
        return try serialized(output)
    }

    /// The serialized `TronSigningOutput` of `input`, whose `raw_data` the device signs.
    static func signTron(
        input: Data,
        sender: String,
        device: @Sendable (_ rawData: Data) async throws -> Data
    ) async throws(MultichainTransactionFailure) -> Data {
        let unsigned = try preImage(coin: .tron, input: input)
        let signature = try await recoveryIdSignature(onDevice { try await device(unsigned.data) })
        try requireSender(sender, coin: .tron, signature: signature, digest: unsigned.dataHash)
        let output: TronSigningOutput = try compile(coin: .tron, input: input, signature: signature)
        guard output.error == .ok, !output.json.isEmpty else {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core failed to compile the tron transaction: \(output.errorMessage)")
        }
        return try serialized(output)
    }

    /// The signature the device makes over `transaction`'s `raw_data`, with `v` as TRON takes it: 27 plus the
    /// recovery id. The transaction comes from the backend rather than ChainKit, as the battery relays it.
    static func signTronTransaction(
        _ transaction: TronSwift.Transaction,
        sender: String,
        device: @Sendable (_ rawData: Data) async throws -> Data
    ) async throws(MultichainTransactionFailure) -> Data {
        let rawData: Data
        let digest: Data
        do {
            rawData = try Data(transaction.rawDataBytes())
            digest = try transaction.signingDigest()
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "the tron transaction cannot be signed: \(error.logDescription)")
        }
        let signature = try await recoveryIdSignature(onDevice { try await device(rawData) })
        try requireSender(sender, coin: .tron, signature: signature, digest: digest)
        var tronSignature = Data(signature.prefix(64))
        tronSignature.append(contentsOf: signature.suffix(1).map { $0 + 27 })
        return tronSignature
    }

    /// The serialized `SolanaSigningOutput` of `input`, whose message the device signs.
    static func signSolana(
        input: Data,
        sender: String,
        device: @Sendable (_ message: Data) async throws -> Data
    ) async throws(MultichainTransactionFailure) -> Data {
        guard let senderKey = WalletCore.Base58.decodeNoCheck(string: sender), let publicKey = WalletCore.PublicKey(data: senderKey, type: .ed25519) else {
            throw .failedToSign(kind: .signInternalError, reason: "the solana sender \(sender) is not a key")
        }
        let unsigned = try preImage(coin: .solana, input: input)
        let signature = try await onDevice { try await device(unsigned.data) }
        guard publicKey.verify(signature: signature, message: unsigned.data) else {
            throw .failedToSign(kind: .unknown, reason: "the device signature does not verify with the sender \(sender)")
        }
        let output: SolanaSigningOutput = try compile(coin: .solana, input: input, signature: signature, publicKey: senderKey)
        guard output.error == .ok, !output.encoded.isEmpty else {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core failed to compile the solana transaction: \(output.errorMessage)")
        }
        return try serialized(output)
    }

    static func tokenContract(of input: EthereumSigningInput) -> String? {
        switch input.transaction.transactionOneof {
        case .erc20Transfer, .erc20Approve:
            return input.toAddress
        default:
            return nil
        }
    }
}

extension DeviceTransactionSigner {
    static func signingInput<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger
    ) async throws(MultichainTransactionFailure) -> Data {
        let built: SignRes<SigSet<I>>
        do {
            built = try await mediator.sign.transaction.buildSigningInput(
                transaction: transaction,
                fee: fee,
                nonce: nonce,
                privateKey: nil
            )
        } catch {
            throw .failedToSign(kind: .unknown, reason: "chain kit failed to build the signing input due to error: \(error.logDescription)")
        }
        guard let input = built.getOrNull()?.firstOutput() else {
            let chainKitError = built.error
            throw .failedToSign(
                kind: ChainKitErrorKindClassifier.kind(signError: chainKitError),
                reason: "chain kit failed to build the signing input due to error: \(chainKitError.map(\.logValue) ?? "unknown")"
            )
        }
        return mediator.sign.transaction.inputAdapter.encode(value: input).asData
    }

    static func preImage(coin: WalletCore.CoinType, input: Data) throws(MultichainTransactionFailure) -> TxCompilerPreSigningOutput {
        let unsigned: TxCompilerPreSigningOutput
        do {
            unsigned = try TxCompilerPreSigningOutput(serializedBytes: TransactionCompiler.preImageHashes(coinType: coin, txInputData: input))
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core cannot read the \(coin) signing input: \(error.localizedDescription)")
        }
        guard unsigned.error == .ok else {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core failed to hash the \(coin) transaction: \(unsigned.errorMessage)")
        }
        return unsigned
    }

    static func onDevice<Signed>(_ sign: () async throws -> Signed) async throws(MultichainTransactionFailure) -> Signed {
        do {
            return try await sign()
        } catch is CancellationError {
            throw .canceled
        } catch {
            throw .failedToSign(kind: .unknown, reason: "the device failed to sign: \(error.logDescription)")
        }
    }

    /// A device may give `v` as `27 + recovery id`; WalletCore takes the recovery id.
    static func recoveryIdSignature(_ signature: Data) throws(MultichainTransactionFailure) -> Data {
        guard signature.count == 65, let v = signature.last else {
            throw .failedToSign(kind: .unknown, reason: "the device returned a \(signature.count)-byte signature")
        }
        return signature.prefix(64) + [v >= 27 ? v - 27 : v]
    }

    static func requireSender(_ sender: String, coin: WalletCore.CoinType, signature: Data, digest: Data) throws(MultichainTransactionFailure) {
        let signer = WalletCore.PublicKey.recover(signature: signature, message: digest)
            .map { coin.deriveAddressFromPublicKey(publicKey: $0) }
        // An EVM address may come with or without its checksum casing; a Tron one is case-sensitive.
        guard let signer, coin == .ethereum ? signer.lowercased() == sender.lowercased() : signer == sender else {
            throw .failedToSign(kind: .unknown, reason: "the device signed for \(signer ?? "no key"), the sender is \(sender)")
        }
    }

    static func compile<Output: WalletCoreSwiftProtobuf.Message>(
        coin: WalletCore.CoinType,
        input: Data,
        signature: Data,
        publicKey: Data? = nil
    ) throws(MultichainTransactionFailure) -> Output {
        do {
            return try Output(serializedBytes: TransactionCompiler.compileWithSignatures(
                coinType: coin,
                txInputData: input,
                signatures: DataVector(data: signature),
                publicKeys: publicKey.map { DataVector(data: $0) } ?? DataVector()
            ))
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "wallet core returned an unreadable \(coin) output: \(error.localizedDescription)")
        }
    }

    static func serialized(_ output: some WalletCoreSwiftProtobuf.Message) throws(MultichainTransactionFailure) -> Data {
        do {
            return try output.serializedBytes()
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "failed to encode the signed transaction: \(error.localizedDescription)")
        }
    }
}
