import Foundation

final class PerpsTradingRecovery: Sendable {
    private enum Pass {
        case requested
        case retry
    }

    private static let autoCloseRenewalCheckInterval: TimeInterval = 60 * 60

    private let passes: AsyncStream<Pass>.Continuation
    private let renewals: AsyncStream<[Int64]>.Continuation
    private let workers: [Task<Void, Never>]

    init(
        recover: @escaping @Sendable () async -> Bool,
        renewAutoClose: @escaping @Sendable (_ marketIds: [Int64]) async -> Bool,
        sleep: @escaping @Sendable (_ nanoseconds: UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let (requestedPasses, passes) = AsyncStream<Pass>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let (requestedRenewals, renewals) = AsyncStream<[Int64]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.passes = passes
        self.renewals = renewals
        workers = [
            Task {
                var unfinishedPasses = 0
                var retry: Task<Void, Never>?
                for await pass in requestedPasses {
                    guard !Task.isCancelled else { break }
                    retry?.cancel()
                    if pass == .requested { unfinishedPasses = 0 }
                    if await recover() { continue }
                    let delay = Self.retryDelay(afterUnfinishedPasses: unfinishedPasses)
                    unfinishedPasses += 1
                    retry = Task {
                        try? await sleep(delay)
                        guard !Task.isCancelled else { return }
                        passes.yield(.retry)
                    }
                }
                retry?.cancel()
            },
            Task {
                var renewedAt: Date?
                for await marketIds in requestedRenewals where !marketIds.isEmpty {
                    guard !Task.isCancelled else { break }
                    let requestedAt = now()
                    if let renewedAt, requestedAt.timeIntervalSince(renewedAt) < Self.autoCloseRenewalCheckInterval {
                        continue
                    }
                    if await renewAutoClose(marketIds) {
                        renewedAt = requestedAt
                    }
                }
            },
        ]
    }

    deinit {
        workers.forEach { $0.cancel() }
    }

    func recover() {
        passes.yield(.requested)
    }

    func renewAutoClose(marketIds: [Int64]) {
        renewals.yield(marketIds)
    }

    private static func retryDelay(afterUnfinishedPasses count: Int) -> UInt64 {
        min(5_000_000_000 << UInt64(min(count, 4)), 60_000_000_000)
    }
}
