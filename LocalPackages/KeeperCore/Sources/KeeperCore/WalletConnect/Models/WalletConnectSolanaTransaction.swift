import Foundation

public struct WalletConnectSolanaTransaction: Sendable, Equatable {
    public var pubkey: String?
    public var transaction: String

    public init(
        pubkey: String?,
        transaction: String
    ) {
        self.pubkey = pubkey
        self.transaction = transaction
    }
}

public struct WalletConnectSolanaTransactionBatch: Sendable, Equatable {
    public var pubkey: String?
    public var transactions: [String]

    public init(
        pubkey: String?,
        transactions: [String]
    ) {
        self.pubkey = pubkey
        self.transactions = transactions
    }
}
