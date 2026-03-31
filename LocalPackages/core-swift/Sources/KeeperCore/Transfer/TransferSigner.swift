import Foundation
import TonSwift

public enum TransferSigner {
    public static func signWalletTransfer(
        _ walletTransfer: WalletTransfer,
        wallet: Wallet,
        seqno: UInt64,
        signer: WalletTransferSigner
    ) throws -> Cell {
        let signed = try walletTransfer.signMessage(
            signer: signer,
            hashModifier: wallet.network == .tetra
                ? { TransferSignaturePrefixedHash.prefixedHash(prefixId: Int32(Network.tetra.rawValue), hash: $0) }
                : nil
        )
        let body = Builder()

        switch walletTransfer.signaturePosition {
        case .front:
            try body.store(data: signed)
            try body.store(walletTransfer.signingMessage)
        case .tail:
            try body.store(walletTransfer.signingMessage)
            try body.store(data: signed)
        }
        let transferCell = try body.endCell()
        let externalMessage = try Message.external(
            to: wallet.address,
            stateInit: seqno == 0 ? wallet.contract.stateInit : nil,
            body: transferCell
        )
        return try Builder().store(externalMessage).endCell()
    }

    public static func signWalletTransfer(
        _ signingMessage: Builder,
        signaturePosition: SignaturePosition,
        wallet: Wallet,
        seqno: UInt64,
        signed: Data
    ) throws -> Cell {
        let body = Builder()

        switch signaturePosition {
        case .front:
            try body.store(data: signed)
            try body.store(signingMessage)
        case .tail:
            try body.store(signingMessage)
            try body.store(data: signed)
        }
        let transferCell = try body.endCell()
        let externalMessage = try Message.external(
            to: wallet.address,
            stateInit: seqno == 0 ? wallet.contract.stateInit : nil,
            body: transferCell
        )
        return try Builder().store(externalMessage).endCell()
    }
}
