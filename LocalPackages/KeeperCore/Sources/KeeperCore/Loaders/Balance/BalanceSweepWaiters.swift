import Foundation

/// Everyone awaiting the wallets-list sweep. They are answered together — the sweep reports through
/// the stores, so the only thing a caller learns from it is that it is over.
final class BalanceSweepWaiters {
    private enum Waiter {
        /// Reserved and not yet registered, so a retirement arriving first has somewhere to land.
        case reserved
        case waiting(continuation: CheckedContinuation<Void, Never>)
        case retired
    }

    private let lock = NSLock()
    private var waiters = [UInt64: Waiter]()
    private var nextId: UInt64 = 0

    var isEmpty: Bool {
        lock.withLock { waiters.isEmpty }
    }

    /// Counts only the waits that are actually installed: one that has reserved its place has not
    /// asked the throttle for anything yet, so it needs no run started on its behalf.
    var hasWaiters: Bool {
        lock.withLock {
            waiters.values.contains { waiter in
                guard case .waiting = waiter else { return false }
                return true
            }
        }
    }

    func reserve() -> UInt64 {
        lock.withLock {
            nextId += 1
            waiters[nextId] = .reserved
            return nextId
        }
    }

    func register(_ id: UInt64, continuation: CheckedContinuation<Void, Never>) -> Bool {
        lock.withLock {
            guard case .reserved = waiters[id] else {
                waiters.removeValue(forKey: id)
                return false
            }
            waiters[id] = .waiting(continuation: continuation)
            return true
        }
    }

    /// Lets one caller go without answering the rest: the sweep they are waiting on is still
    /// running, and telling them it is over would be a lie.
    func retire(_ id: UInt64) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            switch waiters[id] {
            case let .waiting(continuation):
                waiters.removeValue(forKey: id)
                return continuation
            case .reserved:
                waiters[id] = .retired
                return nil
            case .retired, .none:
                return nil
            }
        }
        continuation?.resume()
    }

    /// Taken and cleared under the lock, resumed after it is released.
    func resumeAll() {
        let resumed = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            var resumed = [CheckedContinuation<Void, Never>]()
            for (id, waiter) in waiters {
                guard case let .waiting(continuation) = waiter else { continue }
                waiters.removeValue(forKey: id)
                resumed.append(continuation)
            }
            return resumed
        }
        for continuation in resumed {
            continuation.resume()
        }
    }
}
