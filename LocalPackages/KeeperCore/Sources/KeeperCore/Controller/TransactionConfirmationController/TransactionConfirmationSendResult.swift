import TKLogging

public struct TransactionConfirmationSendResult: Equatable, Sendable {
    public let pendingTransactions: [MultichainPendingTransaction]

    public init(pendingTransactions: [MultichainPendingTransaction]) {
        self.pendingTransactions = pendingTransactions
    }
}

extension TransactionConfirmationSendResult {
    static let nothingToRecord = TransactionConfirmationSendResult(pendingTransactions: [])

    static func chain(
        _ chain: MultichainChain,
        wallet: Wallet,
        txHashes: [String],
        activityType: MultichainPendingTransaction.ActivityType
    ) -> TransactionConfirmationSendResult {
        guard let walletId = wallet.multichainWalletState?.walletId else {
            return .nothingToRecord
        }
        return TransactionConfirmationSendResult(
            pendingTransactions: txHashes.map { txHash in
                MultichainPendingTransaction(
                    walletId: walletId,
                    chain: chain,
                    network: MultichainNetwork(walletNetwork: wallet.network),
                    txHash: txHash,
                    activityType: activityType
                )
            }
        )
    }

    static func ton(
        wallet: Wallet,
        signedTransactions: SignedTransactions,
        activityType: MultichainPendingTransaction.ActivityType
    ) -> TransactionConfirmationSendResult {
        chain(
            .ton,
            wallet: wallet,
            txHashes: signedTransactions.compactMap { signedBoc in
                do {
                    return try TonMessageHash.hex(signedBocBase64: signedBoc)
                } catch {
                    Log.multichain.e(
                        "failed to derive ton message hash of a broadcast transaction",
                        error: error,
                        extraInfo: ["activityType": activityType.name]
                    )
                    return nil
                }
            },
            activityType: activityType
        )
    }
}
