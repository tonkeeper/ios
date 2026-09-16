import Foundation
import TKLogging
import TronSwiftAPI

/// Polls `wallet/gettransactioninfobyid` until the previous TRON leg is in a block.
///
/// Call order is already USDT → TRX, but Battery relays USDT asynchronously. Without waiting
/// for on-chain confirmation the native TRX sweep can land first and drain free bandwidth
/// the USDT transfer still needs.
struct WalletMigrationTronConfirmationWaiter {
    enum Outcome: Equatable, Sendable {
        case confirmed
        case failed(result: String)
        case timedOut
    }

    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    typealias LoadInfo = @Sendable (String) async throws -> TronTransactionInfoResponse?

    private let loadInfo: LoadInfo
    private let pollInterval: TimeInterval
    private let timeout: TimeInterval
    private let sleep: Sleep
    private let now: @Sendable () -> Date

    init(
        loadInfo: @escaping LoadInfo,
        pollInterval: TimeInterval = 3,
        timeout: TimeInterval = 120,
        sleep: @escaping Sleep = WalletMigrationTronConfirmationWaiter.defaultSleep,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.loadInfo = loadInfo
        self.pollInterval = pollInterval
        self.timeout = timeout
        self.sleep = sleep
        self.now = now
    }

    func wait(txId: String) async throws -> Outcome {
        let deadline = now().addingTimeInterval(timeout)

        while now() < deadline {
            try Task.checkCancellation()

            do {
                if let info = try await loadInfo(txId) {
                    if info.isSuccessful {
                        return .confirmed
                    }
                    return .failed(result: info.receiptResult ?? "FAILED")
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.migration.w("tron confirmation poll failed, retrying", extraInfo: [
                    "txId": txId,
                    "error": "\(error)",
                ])
            }

            let remaining = deadline.timeIntervalSince(now())
            guard remaining > 0 else { break }
            try await sleep(min(pollInterval, remaining))
        }

        Log.migration.w("tron confirmation poll timed out", extraInfo: [
            "txId": txId,
            "timeout": "\(timeout)",
        ])
        return .timedOut
    }
}

extension WalletMigrationTronConfirmationWaiter {
    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }
}
