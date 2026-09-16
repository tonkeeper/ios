import Foundation
import TKLogging

/// Waits for the source wallet's on-chain seqno to reach `minimum` before the next external message
/// is broadcast against it. The flat cadence after an initial delay is tuned to the 5-9s a batch
/// takes to land; an exponential one overshoots that window and notices a landing seconds late.
struct WalletMigrationSeqnoWaiter {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    private let sendService: SendService
    private let initialDelay: TimeInterval
    private let pollInterval: TimeInterval
    private let timeout: TimeInterval
    private let sleep: Sleep
    private let now: @Sendable () -> Date

    init(
        sendService: SendService,
        initialDelay: TimeInterval = 2,
        pollInterval: TimeInterval = 1.5,
        timeout: TimeInterval = 60,
        sleep: @escaping Sleep = WalletMigrationSeqnoWaiter.defaultSleep,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sendService = sendService
        self.initialDelay = initialDelay
        self.pollInterval = pollInterval
        self.timeout = timeout
        self.sleep = sleep
        self.now = now
    }

    /// `false` means the deadline passed with the seqno still behind `minimum`. Cancellation is
    /// thrown; a failed seqno read is not, so a transient error cannot abandon a migration that has
    /// already broadcast part of its batches.
    func wait(wallet: Wallet, minimum: UInt64) async throws -> Bool {
        let deadline = now().addingTimeInterval(timeout)
        var delay = initialDelay

        while now() < deadline {
            try Task.checkCancellation()
            try await sleep(delay)
            // Only the first wait is longer; a failed read must not stretch the cadence either.
            delay = pollInterval
            try Task.checkCancellation()

            do {
                if try await sendService.loadSeqno(wallet: wallet) >= minimum {
                    return true
                }
            } catch {
                Log.migration.w("seqno poll failed, retrying", extraInfo: [
                    "minimum": "\(minimum)",
                    "error": "\(error)",
                ])
                continue
            }
        }

        Log.migration.w("seqno poll timed out", extraInfo: [
            "minimum": "\(minimum)",
            "timeout": "\(timeout)",
        ])
        return false
    }
}

extension WalletMigrationSeqnoWaiter {
    static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }
}
