import Foundation
import TKPerpsAPI

typealias PerpsTradingScreenReads = PerpsSharedReads<String, Components.Schemas.TradingScreen>

/// Overlapping reads of one key share a single request, and a read that succeeded less than
/// `reuseWindow` ago answers the next one. Only successes are shared: a caller whose joined read
/// fails reads on its own, since that request may have gone out before the caller renewed a token.
/// The shared request is not cancelled with a caller that stops waiting for it.
/// `@unchecked Sendable`: `entries` is only touched under `lock`.
final class PerpsSharedReads<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    private struct Entry {
        let id: UUID
        let task: Task<Value, Error>
        var succeededAt: Date?
    }

    private let reuseWindow: TimeInterval
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]

    init(reuseWindow: TimeInterval = 0, now: @escaping @Sendable () -> Date = { Date() }) {
        self.reuseWindow = reuseWindow
        self.now = now
    }

    func value(for key: Key, read: @escaping @Sendable () async throws -> Value) async throws -> Value {
        let (task, joined) = lock.withLock {
            let requestedAt = now()
            if let entry = entries[key], entry.succeededAt.map({ requestedAt.timeIntervalSince($0) < reuseWindow }) ?? true {
                return (entry.task, true)
            }
            let id = UUID()
            let task = Task {
                do {
                    let value = try await read()
                    self.finish(key, id: id, succeeded: true)
                    return value
                } catch {
                    self.finish(key, id: id, succeeded: false)
                    throw error
                }
            }
            entries[key] = Entry(id: id, task: task)
            return (task, false)
        }
        do {
            return try await task.value
        } catch {
            guard joined else { throw error }
            return try await read()
        }
    }

    /// Later calls start their own reads; callers already waiting keep the read in flight.
    func invalidate() {
        lock.withLock { entries.removeAll() }
    }

    private func finish(_ key: Key, id: UUID, succeeded: Bool) {
        lock.withLock {
            guard entries[key]?.id == id else { return }
            if succeeded, reuseWindow > 0 {
                entries[key]?.succeededAt = now()
            } else {
                entries[key] = nil
            }
        }
    }
}

extension PerpsSharedReads where Key == String, Value == Components.Schemas.TradingScreen {
    func tradingScreen(api: PerpsAPI, walletId: String, marketId: Int64) async throws -> Value {
        try await value(for: "\(walletId)/\(marketId)") {
            try await api.tradingScreen(walletId: walletId, marketId: marketId)
        }
    }
}
