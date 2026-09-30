import Foundation
import TonSwift

enum WalletMigrationTransactionSigner {
    enum Error: Swift.Error {
        case failedToParseBody
        case failedToSign
    }

    static func signaturePosition(for wallet: Wallet) throws -> SignaturePosition {
        switch try wallet.contractVersion {
        case .v5Beta, .v5R1:
            return .tail
        default:
            return .front
        }
    }

    static func signAndBuildExternalMessageBOC(
        transaction: WalletMigrationPreparedTransaction,
        wallet: Wallet,
        signer: WalletTransferSigner
    ) throws -> String {
        let unsignedBody = try resolveUnsignedBody(transaction: transaction, wallet: wallet)
        let hash = unsignedBody.hash()

        let signature: Data
        do {
            signature = try signer.signMessage(hash)
        } catch {
            throw Error.failedToSign
        }

        let signaturePosition = try signaturePosition(for: wallet)
        let bodyBuilder = Builder()

        switch signaturePosition {
        case .front:
            try bodyBuilder.store(data: signature)
            try bodyBuilder.store(slice: unsignedBody.beginParse())
        case .tail:
            try bodyBuilder.store(slice: unsignedBody.beginParse())
            try bodyBuilder.store(data: signature)
        }

        let stateInit = try resolveStateInit(
            stateInitBOC: transaction.stateInit,
            wallet: wallet,
            seqno: UInt64(transaction.seqno)
        )
        let externalMessage = try Message.external(
            to: wallet.address,
            stateInit: stateInit,
            body: bodyBuilder.endCell()
        )

        return try Builder().store(externalMessage).endCell().toBoc().base64EncodedString()
    }

    private static func resolveUnsignedBody(
        transaction: WalletMigrationPreparedTransaction,
        wallet: Wallet
    ) throws -> Cell {
        if !transaction.messages.isEmpty {
            return try buildUnsignedBody(
                preparedBodyBOC: transaction.boc,
                messages: transaction.messages,
                wallet: wallet,
                seqno: UInt64(transaction.seqno)
            )
        }

        return try Cell.fromBase64(src: transaction.boc.fixBase64())
    }

    private static func buildUnsignedBody(
        preparedBodyBOC: String,
        messages: [WalletMigrationOutMessage],
        wallet: Wallet,
        seqno: UInt64
    ) throws -> Cell {
        let preparedSlice = try Cell.fromBase64(src: preparedBodyBOC.fixBase64()).beginParse()

        switch try wallet.contractVersion {
        case .v5Beta:
            return try buildV5BetaUnsignedBody(preparedSlice: preparedSlice, messages: messages, seqno: seqno)
        case .v5R1:
            return try buildV5R1UnsignedBody(preparedSlice: preparedSlice, messages: messages, seqno: seqno)
        case .v4R1, .v4R2:
            return try buildV4UnsignedBody(preparedSlice: preparedSlice, messages: messages, seqno: seqno)
        default:
            return try buildV3UnsignedBody(preparedSlice: preparedSlice, messages: messages, seqno: seqno)
        }
    }

    private static func buildV5R1UnsignedBody(
        preparedSlice: Slice,
        messages: [WalletMigrationOutMessage],
        seqno: UInt64
    ) throws -> Cell {
        let opcode = try preparedSlice.loadUint(bits: 32)
        let walletId = try preparedSlice.loadInt(bits: 32)
        let validUntil = try preparedSlice.loadUint(bits: 32)
        _ = try preparedSlice.loadUint(bits: 32)

        let signingMessage = try Builder()
            .store(uint: opcode, bits: 32)
            .store(int: walletId, bits: 32)
            .store(uint: validUntil, bits: 32)
            .store(uint: seqno, bits: 32)
            .store(storeV5R1OutListExtended(messages: messages))

        return try signingMessage.endCell()
    }

    private static func buildV5BetaUnsignedBody(
        preparedSlice: Slice,
        messages: [WalletMigrationOutMessage],
        seqno: UInt64
    ) throws -> Cell {
        let opcode = try preparedSlice.loadUint(bits: 32)
        let walletId = try preparedSlice.loadInt(bits: 32)
        let validUntil = try preparedSlice.loadUint(bits: 32)
        _ = try preparedSlice.loadUint(bits: 32)

        let signingMessage = try Builder()
            .store(uint: opcode, bits: 32)
            .store(int: walletId, bits: 32)
            .store(uint: validUntil, bits: 32)
            .store(uint: seqno, bits: 32)
            .store(storeV5BetaOutListExtended(messages: messages))

        return try signingMessage.endCell()
    }

    private static func buildV4UnsignedBody(
        preparedSlice: Slice,
        messages: [WalletMigrationOutMessage],
        seqno: UInt64
    ) throws -> Cell {
        let walletId = try preparedSlice.loadUint(bits: 32)
        let timeout = try preparedSlice.loadUint(bits: 32)
        _ = try preparedSlice.loadUint(bits: 32)
        let order = try preparedSlice.loadUint(bits: 8)

        let signingMessage = try Builder()
            .store(uint: walletId, bits: 32)
            .store(uint: timeout, bits: 32)
            .store(uint: seqno, bits: 32)
            .store(uint: order, bits: 8)

        try appendLegacyMessages(signingMessage, messages: messages)
        return try signingMessage.endCell()
    }

    private static func buildV3UnsignedBody(
        preparedSlice: Slice,
        messages: [WalletMigrationOutMessage],
        seqno: UInt64
    ) throws -> Cell {
        let walletId = try preparedSlice.loadUint(bits: 32)
        let timeout = try preparedSlice.loadUint(bits: 32)
        _ = try preparedSlice.loadUint(bits: 32)

        let signingMessage = try Builder()
            .store(uint: walletId, bits: 32)
            .store(uint: timeout, bits: 32)
            .store(uint: seqno, bits: 32)

        try appendLegacyMessages(signingMessage, messages: messages)
        return try signingMessage.endCell()
    }

    private static func appendLegacyMessages(
        _ signingMessage: Builder,
        messages: [WalletMigrationOutMessage]
    ) throws {
        for message in messages {
            let relaxed = try parseMessageRelaxed(from: message.boc)
            try signingMessage.store(uint: UInt64(message.mode), bits: 8)
            try signingMessage.store(ref: Builder().store(relaxed))
        }
    }

    private static func storeV5R1OutListExtended(
        messages: [WalletMigrationOutMessage]
    ) throws -> Builder {
        try Builder()
            .storeMaybe(ref: storeV5OutList(messages: messages).endCell())
            .store(uint: 0, bits: 1)
    }

    private static func storeV5BetaOutListExtended(
        messages: [WalletMigrationOutMessage]
    ) throws -> Builder {
        try Builder()
            .store(uint: 0, bits: 1)
            .store(ref: storeV5OutList(messages: messages))
    }

    private static func storeV5OutList(
        messages: [WalletMigrationOutMessage]
    ) throws -> Builder {
        var latestCell = Builder()

        for message in messages {
            let relaxed = try parseMessageRelaxed(from: message.boc)
            let sendMode = v5SendMode(from: message.mode)
            latestCell = try Builder()
                .store(uint: OpCodes.OUT_ACTION_SEND_MSG_TAG, bits: 32)
                .store(uint: sendMode, bits: 8)
                .store(ref: latestCell.endCell())
                .store(ref: Builder().store(relaxed))
        }

        return latestCell
    }

    /// Wallet v5 requires the ignore-errors bit (+2) for external messages; otherwise exit code 137.
    private static func v5SendMode(from apiMode: Int) -> UInt64 {
        UInt64(apiMode) | UInt64(SendMode(payMsgFees: false, ignoreErrors: true).rawValue)
    }

    private static func parseMessageRelaxed(from boc: String) throws -> MessageRelaxed {
        let cell = try Cell.fromBase64(src: boc.fixBase64())
        return try MessageRelaxed.loadFrom(slice: cell.beginParse())
    }

    private static func resolveStateInit(
        stateInitBOC: String?,
        wallet: Wallet,
        seqno: UInt64
    ) throws -> StateInit? {
        if let stateInitBOC, !stateInitBOC.isEmpty {
            return try StateInit.loadFrom(
                slice: Cell
                    .fromBase64(src: stateInitBOC.fixBase64())
                    .toSlice()
            )
        }
        if seqno == 0 {
            return try wallet.contract.stateInit
        }
        return nil
    }
}
