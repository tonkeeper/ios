import BigInt
import ChainKit
import Foundation
import TonSwift
import TonTransport
import WalletCore
import WalletCoreSwiftProtobuf

extension DeviceTransactionSigner {
    /// How long TON transactions signed on the device stay valid: the user confirms each of them, and each
    /// goes out only once the one before it has landed.
    static let tonValidity: TimeInterval = 600

    /// The TON app signs a transaction of one message, so every message of `transactions` leaves as its own
    /// transaction, at consecutive seqnos from `nonce`. Returns the external messages, to be sent in order.
    static func signTon<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transactions: [any ChainKit.Transaction],
        fee: any Fee,
        nonce: BignumBigInteger,
        wallet: Wallet,
        device: @Sendable ([LedgerTonTransaction]) async throws -> [Data]
    ) async throws(MultichainTransactionFailure) -> [KotlinByteArray] {
        var inputs = [TheOpenNetworkSigningInput]()
        for transaction in transactions {
            let input = try await signingInput(mediator: mediator, transaction: transaction, fee: fee, nonce: nonce)
            do {
                try inputs.append(TheOpenNetworkSigningInput(serializedBytes: input))
            } catch {
                throw .failedToSign(kind: .signInternalError, reason: "wallet core cannot read the ton signing input: \(error.localizedDescription)")
            }
        }
        let timeout = UInt64(Date().addingTimeInterval(tonValidity).timeIntervalSince1970)
        let unsigned = try tonTransactions(inputs, timeout: timeout)
        let signatures = try await onDevice { try await device(unsigned) }
        guard signatures.count == unsigned.count else {
            throw .failedToSign(kind: .unknown, reason: "the device returned \(signatures.count) signatures for \(unsigned.count) ton transactions")
        }
        return try zip(unsigned, signatures).map { transaction, signature throws(MultichainTransactionFailure) in
            try tonExternalMessage(transaction, signature: signature, wallet: wallet).asKotlinByteArray
        }
    }

    /// The transactions the TON app signs for `inputs`: one per message, at consecutive seqnos from the first input's.
    static func tonTransactions(_ inputs: [TheOpenNetworkSigningInput], timeout: UInt64) throws(MultichainTransactionFailure) -> [LedgerTonTransaction] {
        guard let first = inputs.first, inputs.allSatisfy({ $0.sequenceNumber == first.sequenceNumber }) else {
            throw .failedToSign(kind: .signInternalError, reason: "ton signing inputs disagree on the seqno")
        }
        guard first.walletVersion == .walletV4R2 else {
            throw .failedToSign(kind: .signInternalError, reason: "the ton app signs only for a v4R2 wallet, got \(first.walletVersion)")
        }
        do {
            return try inputs.flatMap(\.messages).enumerated().map { index, message in
                guard let sendMode = SendMode(rawValue: UInt8(truncatingIfNeeded: message.mode)) else {
                    throw MultichainTransactionFailure.failedToSign(kind: .signInternalError, reason: "ton send mode \(message.mode) is not valid")
                }
                return try LedgerTonTransaction(
                    destination: Address.parse(message.dest),
                    sendMode: sendMode,
                    seqno: UInt64(first.sequenceNumber) + UInt64(index),
                    timeout: timeout,
                    bounceable: message.bounceable,
                    coins: coins(message.amount),
                    stateInit: message.stateInit.isEmpty ? nil : StateInit.loadFrom(slice: Cell.fromBase64(src: message.stateInit).beginParse()),
                    payload: tonPayload(of: message)
                )
            }
        } catch let failure as MultichainTransactionFailure {
            throw failure
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "a ton message cannot be put to the device: \(error.localizedDescription)")
        }
    }

    /// The serialized `TheOpenNetworkSigningOutput` of `transaction` with the device's signature of its signing message.
    static func tonExternalMessage(_ transaction: LedgerTonTransaction, signature: Data, wallet: Wallet) throws(MultichainTransactionFailure) -> Data {
        let message: Cell
        do {
            message = try TransferSigner.signWalletTransfer(
                TonTransport.buildTransfer(transaction: transaction).signingMessage,
                signaturePosition: .front,
                wallet: wallet,
                seqno: transaction.seqno,
                signed: signature
            )
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "failed to build the ton external message: \(error.localizedDescription)")
        }
        do {
            let output = try TheOpenNetworkSigningOutput.with {
                $0.encoded = try message.toBoc().base64EncodedString()
                $0.hash = message.hash()
            }
            return try serialized(output)
        } catch let failure as MultichainTransactionFailure {
            throw failure
        } catch {
            throw .failedToSign(kind: .signInternalError, reason: "failed to encode the ton external message: \(error.localizedDescription)")
        }
    }
}

private extension DeviceTransactionSigner {
    static func coins(_ amount: Data) throws -> Coins {
        guard let coins = Coins(rawValue: BigUInt(amount)) else {
            throw MultichainTransactionFailure.failedToSign(kind: .signInternalError, reason: "a ton amount is not coins")
        }
        return coins
    }

    /// What the TON app shows for a message's body: a format it knows, or the cell for blind signing.
    static func tonPayload(of message: TheOpenNetworkTransfer) throws -> TonPayloadFormat? {
        let comment = message.comment.isEmpty ? nil : try Builder().store(int: 0, bits: 32).writeSnakeData(Data(message.comment.utf8)).endCell()
        switch message.payload {
        case let .customPayload(payload):
            return try TonPayloadFormat.from(cell: Cell.fromBase64(src: payload))
        case let .jettonTransfer(jetton):
            return try .jettonTransfer(TonPayloadFormat.JettonTransfer(
                queryId: jetton.queryID == 0 ? nil : BigUInt(jetton.queryID),
                coins: coins(jetton.jettonAmount),
                receiverAddress: Address.parse(jetton.toOwner),
                excessesAddress: Address.parse(jetton.responseAddress),
                customPayload: jetton.customPayload.isEmpty ? nil : Cell.fromBase64(src: jetton.customPayload),
                forwardAmount: coins(jetton.forwardAmount),
                forwardPayload: comment
            ))
        case nil:
            return try comment.map { try TonPayloadFormat.from(cell: $0) }
        }
    }
}
