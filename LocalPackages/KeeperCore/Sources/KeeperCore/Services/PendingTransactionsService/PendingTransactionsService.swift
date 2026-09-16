import Foundation
import TKLogging

public protocol PendingTransactionsService: Sendable {
    func report(_ transaction: MultichainPendingTransaction) async
    func flushRetained() async
}

public extension PendingTransactionsService {
    func record(_ result: TransactionConfirmationSendResult, wallet: Wallet) async {
        guard wallet.multichainWalletState != nil else {
            return
        }
        for transaction in result.pendingTransactions {
            await report(transaction)
        }
    }
}

protocol MultichainPendingTransactionWriter {
    func addPendingTransaction(
        _ transaction: MultichainPendingTransaction
    ) async throws(MultichainClientAPIError)
}

struct MultichainPendingTransactionClientWriter: MultichainPendingTransactionWriter {
    let multichainClientAPI: MultichainClientAPI

    func addPendingTransaction(
        _ transaction: MultichainPendingTransaction
    ) async throws(MultichainClientAPIError) {
        try await multichainClientAPI.addPendingTransaction(transaction)
    }
}

actor PendingTransactionsServiceImplementation: PendingTransactionsService {
    static let defaultTimeToLive: TimeInterval = 5 * 60

    private struct RetainedTransaction {
        let transaction: MultichainPendingTransaction
        let expirationDate: Date
    }

    private let writer: MultichainPendingTransactionWriter
    private let timeToLive: TimeInterval
    private let now: () -> Date

    private var retained = [RetainedTransaction]()

    init(
        writer: MultichainPendingTransactionWriter,
        timeToLive: TimeInterval = PendingTransactionsServiceImplementation.defaultTimeToLive,
        now: @escaping () -> Date = Date.init
    ) {
        self.writer = writer
        self.timeToLive = timeToLive
        self.now = now
    }

    func report(_ transaction: MultichainPendingTransaction) async {
        if await send(transaction) {
            return
        }
        retain(
            RetainedTransaction(
                transaction: transaction,
                expirationDate: now().addingTimeInterval(timeToLive)
            )
        )
    }

    func flushRetained() async {
        let due = retained
        retained = []
        guard !due.isEmpty else {
            return
        }
        let deadline = now()
        for entry in due {
            guard entry.expirationDate > deadline else {
                Log.multichain.i(
                    "pending transaction report dropped after time to live",
                    extraInfo: Self.logInfo(entry.transaction)
                )
                continue
            }
            if await send(entry.transaction) {
                continue
            }
            retain(entry)
        }
    }
}

private extension PendingTransactionsServiceImplementation {
    func send(_ transaction: MultichainPendingTransaction) async -> Bool {
        do {
            try await writer.addPendingTransaction(transaction)
            return true
        } catch {
            Log.multichain.w(
                "failed to report pending transaction",
                error: error,
                extraInfo: Self.logInfo(transaction)
            )
            return false
        }
    }

    private func retain(_ entry: RetainedTransaction) {
        guard !retained.contains(where: { $0.transaction == entry.transaction }) else {
            return
        }
        retained.append(entry)
    }

    static func logInfo(_ transaction: MultichainPendingTransaction) -> [String: String] {
        [
            "chain": transaction.chain.rawValue,
            "network": transaction.network.rawValue,
            "txHash": transaction.txHash,
            "activityType": transaction.activityType.name,
        ]
    }
}
