@preconcurrency import AnyCodable
import CryptoKit
import Foundation
import WalletCore

/// Signs WalletConnect and Earn requests on a hardware wallet. Nothing goes back to the dApp before the signature
/// checks out against the wallet's own key.
struct WalletConnectDeviceRequestSigner {
    private let evmUtilities = WalletConnectEVMTransactionSigningUtilities()
    private let solanaUtilities = WalletConnectSolanaSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        switch request.payload {
        case let .signMessage(message):
            try context.validateAddress(message.address, chain: request.chain)
            switch message.kind {
            case .personal:
                return try await .string(signPersonalMessage(message.message, chain: request.chain, context: context, device: device))
            case .typedDataV4:
                return try await .string(signTypedData(message.message, chain: request.chain, context: context, device: device))
            case .tron:
                return try await .object(["signature": signTronMessage(message.message, context: context, device: device)])
            case .solana:
                throw .notImplemented(reason: "a hardware wallet does not sign Solana messages")
            }
        case let .evmTransaction(transaction, send):
            return try await evmUtilities.sign(transaction: transaction, send: send, chain: request.chain, context: context)
        case let .tronTransaction(transaction):
            return try await signTronTransaction(transaction, context: context, device: device)
        case let .solanaTransaction(transaction, send):
            try context.validateAddress(transaction.pubkey, chain: .sol)
            let signed = try await signSolanaTransaction(transaction.transaction, context: context, device: device)
            guard send else {
                return .object(["signature": signed.signature, "transaction": signed.transaction])
            }
            try await context.checkRequestIsPending()
            let signature = try await solanaUtilities.send(
                signed.transaction,
                client: context.client,
                account: context.storedChainKitAccount(chain: .sol)
            )
            await context.reportPendingTransaction(chain: .sol, txHash: signature, activityType: .contractCall)
            return .object(["signature": signature])
        case let .solanaTransactionBatch(batch):
            try context.validateAddress(batch.pubkey, chain: .sol)
            var signedTransactions = [String]()
            for transaction in batch.transactions {
                try await signedTransactions.append(signSolanaTransaction(transaction, context: context, device: device).transaction)
            }
            return .json(AnyCodable(["transactions": signedTransactions]))
        case .tonSendMessage, .tonSignData:
            throw .notImplemented(reason: "\(request.method.rawValue) is not implemented")
        case .switchEthereumChain, .walletCapabilities, .solanaAccounts:
            throw .invalidPayload(reason: "\(request.method.rawValue) is handled without signing")
        }
    }
}

private extension WalletConnectDeviceRequestSigner {
    /// The device signs the bytes WalletCore signs for a mnemonic: the message decoded from hex when it is hex,
    /// its UTF-8 otherwise, and WalletCore checks the result.
    func signPersonalMessage(
        _ message: String,
        chain: WalletConnectChain,
        context: WalletConnectSigningContext,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> String {
        let signature = try await onDevice { try await device.evmMessage(Self.eip191Bytes(message)) }
        let publicKey = try publicKey(chain: chain, context: context, type: .secp256k1Extended)
        guard EthereumMessageSigner.verifyMessage(pubKey: publicKey, message: message, signature: signature.hexString()) else {
            throw .failedToSign(reason: "the device signature does not verify for the message")
        }
        return "0x" + signature.hexString()
    }

    func signTypedData(
        _ json: String,
        chain: WalletConnectChain,
        context: WalletConnectSigningContext,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> String {
        let typedData: EIP712TypedData
        do {
            typedData = try EIP712TypedData(json: json)
        } catch {
            throw .invalidPayload(reason: "typed data is not signable on a hardware wallet: \(error)")
        }
        guard typedData.digest == EthereumAbi.encodeTyped(messageJson: json) else {
            throw .invalidPayload(reason: "typed data hashes disagree with wallet core")
        }
        let signature = try await onDevice {
            try await device.evmTypedData(typedData.domainSeparator, typedData.messageHash)
        }
        let address = try context.accountAddress(chain: chain)
        try requireSigner(address, coin: .ethereum, signature: signature, digest: typedData.digest)
        return "0x" + signature.hexString()
    }

    func signTronMessage(
        _ message: String,
        context: WalletConnectSigningContext,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> String {
        let bytes = Data(message.utf8)
        let signature = try await onDevice { try await device.tronMessage(bytes) }
        let digest = Hash.keccak256(data: Data("\u{19}TRON Signed Message:\n\(bytes.count)".utf8) + bytes)
        try requireSigner(context.accountAddress(chain: .tron), coin: .tron, signature: signature, digest: digest)
        return "0x" + signature.hexString()
    }

    func signTronTransaction(
        _ transaction: WalletConnectTronTransaction,
        context: WalletConnectSigningContext,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard let rawDataHex = transaction.rawDataHex, let rawData = Data(walletConnectHex: rawDataHex), !rawData.isEmpty else {
            throw .invalidTransaction(reason: "tron transaction raw_data_hex is missing or invalid")
        }
        try context.validateAddress(transaction.address, chain: .tron)
        let txID = Data(SHA256.hash(data: rawData))
        let signature = try await Self.withRecoveryV(onDevice { try await device.tron(rawData) })
        try requireSigner(context.accountAddress(chain: .tron), coin: .tron, signature: signature, digest: txID)
        return try .json(WalletConnectTronTransactionSigner.signedTransactionJSON(
            transactionJSON: transaction.transactionJSON,
            signedTransaction: .init(txID: txID.hexString(), signature: signature.hexString())
        ))
    }

    /// Signs a base64 transaction's message as the wallet's account and returns it with the signature in its slot.
    func signSolanaTransaction(
        _ transaction: String,
        context: WalletConnectSigningContext,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> WalletConnectSolanaSignedTransaction {
        guard let bytes = Data(base64Encoded: transaction), var wire = try? SolanaWireTransaction(bytes) else {
            throw .invalidTransaction(reason: "solana transaction is not a serialized transaction")
        }
        let key = try publicKey(chain: .sol, context: context, type: .ed25519)
        guard wire.signers.contains(key.data) else {
            throw .invalidTransaction(reason: "solana transaction does not need the wallet's signature")
        }
        let message = wire.message
        let signature = try await onDevice { try await device.solana(message) }
        guard key.verify(signature: signature, message: message), (try? wire.sign(signature, by: key.data)) != nil else {
            throw .failedToSign(reason: "the device signature does not verify for the solana transaction")
        }
        return WalletConnectSolanaSignedTransaction(
            signature: Base58.encodeNoCheck(data: signature),
            transaction: wire.serialized.base64EncodedString()
        )
    }

    func publicKey(chain: WalletConnectChain, context: WalletConnectSigningContext, type: PublicKeyType) throws(WalletConnectSigningError) -> WalletCore.PublicKey {
        let stored = try context.storedPublicKey(chain: chain)
        guard let data = Data(walletConnectHex: stored.defaultHex), let key = WalletCore.PublicKey(data: data, type: type) else {
            throw .failedToSign(reason: "the wallet's \(chain.caip2) key is not usable")
        }
        return key
    }

    func requireSigner(_ address: String, coin: CoinType, signature: Data, digest: Data) throws(WalletConnectSigningError) {
        guard signature.count == 65 else {
            throw .failedToSign(reason: "the device returned a \(signature.count)-byte signature")
        }
        let recoveryId = signature[signature.startIndex + 64] >= 27 ? signature[signature.startIndex + 64] - 27 : signature[signature.startIndex + 64]
        let signer = WalletCore.PublicKey.recover(signature: signature.prefix(64) + [recoveryId], message: digest)
            .map { coin.deriveAddressFromPublicKey(publicKey: $0) }
        // An EVM address may come with or without its checksum casing; a Tron one is case-sensitive.
        guard let signer, coin == .ethereum ? signer.lowercased() == address.lowercased() : signer == address else {
            throw .failedToSign(reason: "the device signed for \(signer ?? "no key"), the wallet is \(address)")
        }
    }

    func onDevice(_ sign: () async throws -> Data) async throws(WalletConnectSigningError) -> Data {
        do {
            return try await sign()
        } catch is CancellationError {
            throw .canceled
        } catch {
            throw .failedToSign(reason: "the device failed to sign: \(error.logDescription)")
        }
    }

    /// `r ‖ s ‖ v` with `v` 27 or 28, as the app signs a Tron transaction itself.
    static func withRecoveryV(_ signature: Data) -> Data {
        guard signature.count == 65, let v = signature.last else {
            return signature
        }
        return signature.prefix(64) + [v < 27 ? v + 27 : v]
    }

    /// As WalletCore reads a `personal_sign` message: hex, with or without `0x`, when it is hex.
    static func eip191Bytes(_ message: String) -> Data {
        let hex = message.hasPrefix("0x") ? String(message.dropFirst(2)) : message
        guard hex.count.isMultiple(of: 2), hex.allSatisfy(\.isHexDigit), let bytes = Data(walletConnectHex: hex) else {
            return Data(message.utf8)
        }
        return bytes
    }
}
