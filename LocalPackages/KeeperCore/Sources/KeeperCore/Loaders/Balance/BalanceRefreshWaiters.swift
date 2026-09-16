import Foundation

/// Its own isolation domain so the continuations get one owner, and so a cancellation handler can
/// retire a wait without capturing the loader.
final class BalanceRefreshWaiters: @unchecked Sendable {
    private enum Waiter {
        /// Reserved and not yet registered, so a retirement arriving first has somewhere to land.
        case reserved
        case waiting(wallet: Wallet, continuation: CheckedContinuation<BalanceRefreshResult, Never>)
        case retired
    }

    private let lock = NSLock()
    private var waiters = [UInt64: Waiter]()
    private var nextId: UInt64 = 0

    var isEmpty: Bool {
        lock.withLock { waiters.isEmpty }
    }

    /// Whether anyone is still waiting on this wallet — asked when a run ends with nothing queued,
    /// to tell a wait nobody answered from the usual case of none being left.
    func hasWaiters(for wallet: Wallet) -> Bool {
        lock.withLock {
            waiters.values.contains { waiter in
                guard case let .waiting(waitingWallet, _) = waiter else { return false }
                return waitingWallet == wallet
            }
        }
    }

    func isWaiting(_ id: UInt64) -> Bool {
        lock.withLock {
            guard case .waiting = waiters[id] else { return false }
            return true
        }
    }

    func reserve() -> UInt64 {
        lock.withLock {
            nextId += 1
            waiters[nextId] = .reserved
            return nextId
        }
    }

    func register(
        _ id: UInt64,
        wallet: Wallet,
        continuation: CheckedContinuation<BalanceRefreshResult, Never>
    ) -> Bool {
        lock.withLock {
            guard case .reserved = waiters[id] else {
                waiters.removeValue(forKey: id)
                return false
            }
            waiters[id] = .waiting(wallet: wallet, continuation: continuation)
            return true
        }
    }

    func retire(_ id: UInt64) {
        let continuation = lock.withLock { () -> CheckedContinuation<BalanceRefreshResult, Never>? in
            switch waiters[id] {
            case let .waiting(_, continuation):
                waiters.removeValue(forKey: id)
                return continuation
            case .reserved:
                waiters[id] = .retired
                return nil
            case .retired, .none:
                return nil
            }
        }
        continuation?.resume(returning: .dropped)
    }

    func settle(_ wallet: Wallet, result: BalanceRefreshResult) {
        resume(take { $0 == wallet }, with: result)
    }

    func settleAll(result: BalanceRefreshResult) {
        resume(take { _ in true }, with: result)
    }

    /// Taken and cleared under the lock, resumed after it is released.
    private func take(
        matching isMatch: (Wallet) -> Bool
    ) -> [CheckedContinuation<BalanceRefreshResult, Never>] {
        lock.withLock {
            var taken = [CheckedContinuation<BalanceRefreshResult, Never>]()
            for (id, waiter) in waiters {
                guard case let .waiting(wallet, continuation) = waiter, isMatch(wallet) else {
                    continue
                }
                waiters.removeValue(forKey: id)
                taken.append(continuation)
            }
            return taken
        }
    }

    private func resume(
        _ continuations: [CheckedContinuation<BalanceRefreshResult, Never>],
        with result: BalanceRefreshResult
    ) {
        for continuation in continuations {
            continuation.resume(returning: result)
        }
    }
}
