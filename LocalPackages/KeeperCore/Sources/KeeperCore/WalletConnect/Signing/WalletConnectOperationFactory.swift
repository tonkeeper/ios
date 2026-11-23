import ChainKit
import Foundation

/// What a dApp's request is signed as, the way chain-kit reads it: each payload wraps exactly what the
/// request's signer signs, read from the account of the address that signs it, with its stored key.
enum WalletConnectOperationFactory {
    /// One operation under the request's id, a TRON transaction under its own. Nothing for a request no
    /// signer here signs: WalletConnect TON, and a Solana message on a hardware wallet.
    static func signables(of request: WalletConnectSessionRequest, wallet: Wallet) throws -> [SignableOperation] {
        let payloads: [(type: String, meta: [String: Any])]
        switch request.payload {
        case let .evmTransaction(transaction, _):
            return try [evmTransaction(transaction, of: request, wallet: wallet, fidelity: .exactWrap)]
        case let .signMessage(message):
            switch message.kind {
            case .personal:
                // chain-kit reads a message as bytes only when it is hex with `0x`.
                payloads = [("message/plain", ["message": "0x" + personalMessageBytes(message.message).hexString()])]
            case .typedDataV4:
                payloads = [("message/eip712", ["data": message.message])]
            case .solana where wallet.isLedger:
                return []
            case .tron:
                return try [tronMessage(message.message, of: request, wallet: wallet, fidelity: .exactWrap)]
            case .solana:
                payloads = [("message/plain", ["message": message.message])]
            }
        case let .solanaTransaction(transaction, _):
            payloads = [("prebuild", ["data": transaction.transaction])]
        case let .solanaTransactionBatch(batch):
            payloads = batch.transactions.map { ("prebuild", ["data": $0]) }
        case let .tronTransaction(transaction):
            guard let rawDataHex = transaction.rawDataHex,
                  var document = transaction.transactionJSON.walletConnectObjectValue
            else {
                throw WalletConnectSigningError.invalidTransaction(reason: "tron transaction is not a JSON object with its raw_data_hex")
            }
            // chain-kit holds the signed bytes to their txID, which a dApp may leave out.
            let txID = try WalletConnectTronTransactionSigner.txID(rawDataHex: rawDataHex)
            document["txID"] = txID
            return try [.tronPrebuild(document, txID: txID, account: account(signing: request, on: wallet), intent: .dapp)]
        case .tonSendMessage, .tonSignData, .switchEthereumChain, .walletCapabilities, .solanaAccounts:
            return []
        }
        return try [
            .parsed(id: request.id, payloads: payloads, account: account(signing: request, on: wallet), intent: .dapp, fidelity: .exactWrap),
        ]
    }

    /// An EVM transaction as the one `main` chain-kit signs it as: its call, without the dApp's gas.
    /// The SDK signs that very call, so its review wraps what is signed; signed as this operation, the
    /// review is exact.
    static func evmTransaction(
        _ transaction: WalletConnectEVMTransaction,
        of request: WalletConnectSessionRequest,
        wallet: Wallet,
        fidelity: SignableOperation.Fidelity
    ) throws -> SignableOperation {
        let call = try WalletConnectEVMTransactionSigningUtilities().call(transaction, on: request.chain)
        var main: [String: Any] = ["to": call.to.display, "value": call.value.description]
        main["data"] = call.data
        return try .parsed(id: request.id, payloads: [("main", main)], account: account(signing: request, on: wallet), intent: .dapp, fidelity: fidelity)
    }

    /// A TRON message as the `message/plain` chain-kit signs it: TIP-191 over the text, as the SDK's
    /// signer signs it, so its review wraps what is signed; signed as this operation, the review is exact.
    static func tronMessage(
        _ message: String,
        of request: WalletConnectSessionRequest,
        wallet: Wallet,
        fidelity: SignableOperation.Fidelity
    ) throws -> SignableOperation {
        try .parsed(
            id: request.id,
            payloads: [("message/plain", ["message": message])],
            account: account(signing: request, on: wallet),
            intent: .dapp,
            fidelity: fidelity
        )
    }
}

private extension WalletConnectOperationFactory {
    static func account(signing request: WalletConnectSessionRequest, on wallet: Wallet) throws -> ChainKit.Account {
        try ChainKitOperationSender.account(wallet: wallet, chain: request.chain.multichainChain)
    }

    /// What WalletCore signs for a `personal_sign` message, and holds a device's signature to: hex
    /// once every leading `0x` is dropped, the whole message's UTF-8 otherwise. The device signer
    /// drops one `0x`; where that reads other bytes, its signature fails the check.
    static func personalMessageBytes(_ message: String) -> Data {
        var hex = Substring(message)
        while hex.hasPrefix("0x") {
            hex = hex.dropFirst(2)
        }
        guard hex.allSatisfy(\.isHexDigit), let bytes = Data(walletConnectHex: String(hex)) else {
            return Data(message.utf8)
        }
        return bytes
    }
}
