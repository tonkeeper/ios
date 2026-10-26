import Foundation

struct WalletConnectSolanaSignTransactionParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()
    private let send: Bool

    init(send: Bool) {
        self.send = send
    }

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = send ? .solanaSignAndSendTransaction : .solanaSignTransaction
        struct Params: Decodable {
            var pubkey: String?
            var transaction: String
        }
        let params = try utilities.decode(
            Params.self,
            from: paramsJSON,
            method: method
        ) { error in
            "failed to decode solana transaction: \(error)"
        }
        try WalletConnectSolanaTransactionEncoding.validate(params.transaction, method: method)

        return .solanaTransaction(
            WalletConnectSolanaTransaction(
                pubkey: params.pubkey,
                transaction: params.transaction
            ),
            send: send
        )
    }
}

struct WalletConnectSolanaSignAllTransactionsParser: WalletConnectMethodPayloadParser {
    private let utilities = WalletConnectMethodParsingUtilities()

    func parse(
        chain _: WalletConnectChain,
        paramsJSON: String
    ) throws(WalletConnectRequestParsingError) -> WalletConnectRequestPayload {
        let method: WalletConnectMethod = .solanaSignAllTransactions
        struct Params: Decodable {
            var pubkey: String?
            var transactions: [String]
        }
        let params = try utilities.decode(
            Params.self,
            from: paramsJSON,
            method: method
        ) { error in
            "failed to decode solana transactions: \(error)"
        }
        guard !params.transactions.isEmpty else {
            throw .invalidParams(method: method, reason: "solana transactions are empty")
        }
        for transaction in params.transactions {
            try WalletConnectSolanaTransactionEncoding.validate(transaction, method: method)
        }

        return .solanaTransactionBatch(
            WalletConnectSolanaTransactionBatch(
                pubkey: params.pubkey,
                transactions: params.transactions
            )
        )
    }
}

enum WalletConnectSolanaTransactionEncoding {
    static func validate(
        _ transaction: String,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) {
        guard let bytes = Data(base64Encoded: transaction), !bytes.isEmpty else {
            throw .invalidParams(method: method, reason: "solana transaction is not base64")
        }
    }
}
