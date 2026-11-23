import ChainKit
import Foundation
import TonSwift
import TronSwift

extension SignableOperation {
    /// The request a TON wallet signs, written into a BOC once. TonSwift orders the cells of a BOC
    /// by iterating a `Set`, so the same request written again can read as another operation.
    struct TonRequest {
        let hash: String
        let boc: String

        init(signing walletTransfer: WalletTransfer) throws {
            let request = try walletTransfer.signingMessage.endCell()
            hash = request.hash().hexString()
            boc = try request.toBoc().base64EncodedString()
        }
    }

    /// What a TON wallet signs: the request its contract checks the signature of, as an `ext_msg`
    /// prebuild. chain-kit reads the requests of a v4R2 and a W5 wallet only.
    static func ton(
        _ request: TonRequest,
        of wallet: Wallet,
        account: ChainKit.Account,
        intent: OperationIntent,
        fidelity: Fidelity
    ) throws -> SignableOperation {
        let version = try wallet.contractVersion
        let walletVersion: String
        switch version {
        case .v4R2:
            walletVersion = "v4r2"
        case .v5R1:
            walletVersion = "v5r1"
        case .v3R1, .v3R2, .v4R1, .v5Beta, .walletTg:
            throw ChainKitOperationError.unsupportedAccount("ton \(version.rawValue)")
        }
        return try parsed(
            id: request.hash,
            payloads: [("prebuild", ["wallet_version": walletVersion, "format": "ext_msg", "data": request.boc])],
            account: account,
            intent: intent,
            fidelity: fidelity
        )
    }

    /// The transaction a TRON node built, as the wallet signs it: its `txID` is the hash of the
    /// `raw_data_hex` it carries.
    static func tronPrebuild(
        _ transaction: TronSwift.Transaction,
        account: ChainKit.Account,
        intent: OperationIntent
    ) throws -> SignableOperation {
        try tronPrebuild(transaction.toJson(), txID: transaction.txID, account: account, intent: intent)
    }

    /// A TRON transaction document as the wallet signs it, under its `txID`: the hash of the
    /// `raw_data_hex` the document carries.
    static func tronPrebuild(
        _ document: [String: Any],
        txID: String,
        account: ChainKit.Account,
        intent: OperationIntent
    ) throws -> SignableOperation {
        try parsed(id: txID, payloads: [("prebuild", ["data": document])], account: account, intent: intent, fidelity: .exactWrap)
    }

    /// An operation of `payloads`, each a `meta` chain-kit reads by its `type`, read from the JSON a
    /// backend would send it, so a shape it refuses is an error rather than a crash. A payload is
    /// named by the operation, and by its place in it when there are several.
    static func parsed(
        id: String,
        payloads: [(type: String, meta: [String: Any])],
        account: ChainKit.Account,
        intent: OperationIntent,
        fidelity: Fidelity
    ) throws -> SignableOperation {
        let envelopes: [[String: Any]] = payloads.enumerated().map { index, payload in
            [
                "chain_id": account.chain.caip2,
                "id": payloads.count == 1 ? id : "\(id)/\(index)",
                "type": payload.type,
                "version": 1,
                "meta": payload.meta,
            ]
        }
        guard JSONSerialization.isValidJSONObject(envelopes) else {
            throw ChainKitOperationError.malformed(id)
        }
        // The review id reads this JSON: sorted keys write the same payload the same way.
        let json = try JSONSerialization.data(withJSONObject: envelopes, options: .sortedKeys)
        return try SignableOperation(
            operation: ChainKitOperationSender.parse(id: id, payloads: String(decoding: json, as: UTF8.self)),
            account: account,
            intent: intent,
            fidelity: fidelity
        )
    }
}
