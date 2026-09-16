import Foundation
import TKLogging

/// Polls Battery `GET /status` until `pending_transactions` is empty so the next sponsored
/// send is accepted by the relayer.
struct WalletMigrationBatteryIdleWaiter {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    typealias HasPending = @Sendable (Wallet) async throws -> Bool

    private let hasPendingTransactions: HasPending
    private let initialDelay: TimeInterval
    private let pollInterval: TimeInterval
    private let timeout: TimeInterval
    private let sleep: Sleep
    private let now: @Sendable () -> Date

    init(
        batteryService: BatteryService,
        initialDelay: TimeInterval = 1,
        pollInterval: TimeInterval = 1.5,
        timeout: TimeInterval = 60,
        sleep: @escaping Sleep = WalletMigrationBatteryIdleWaiter.defaultSleep,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.init(
            hasPendingTransactions: { wallet in
                try await batteryService.hasPendingTransactions(wallet: wallet)
            },
            initialDelay: initialDelay,
            pollInterval: pollInterval,
            timeout: timeout,
            sleep: sleep,
            now: now
        )
    }

    init(
        hasPendingTransactions: @escaping HasPending,
        initialDelay: TimeInterval = 1,
        pollInterval: TimeInterval = 1.5,
        timeout: TimeInterval = 60,
        sleep: @escaping Sleep = WalletMigrationBatteryIdleWaiter.defaultSleep,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.hasPendingTransactions = hasPendingTransactions
        self.initialDelay = initialDelay
        self.pollInterval = pollInterval
        self.timeout = timeout
        self.sleep = sleep
        self.now = now
    }

    /// `false` means the deadline passed with the lock still held. Cancellation is thrown; a
    /// failed status read is not, so a transient error cannot abandon a migration that has
    /// already broadcast part of its batches.
    func wait(wallet: Wallet) async throws -> Bool {
        let deadline = now().addingTimeInterval(timeout)
        var delay = initialDelay

        while now() < deadline {
            try Task.checkCancellation()
            try await sleep(delay)
            delay = pollInterval
            try Task.checkCancellation()

            do {
                if try await hasPendingTransactions(wallet) == false {
                    return true
                }
            } catch {
                Log.migration.w("battery status poll failed, retrying", extraInfo: [
                    "error": "\(error)",
                ])
                continue
            }
        }

        Log.migration.w("battery idle poll timed out", extraInfo: [
            "timeout": "\(timeout)",
        ])
        return false
    }
}

extension WalletMigrationBatteryIdleWaiter {
    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }
}
