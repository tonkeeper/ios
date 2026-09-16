import Foundation

/// Serializes requests per key.
///
/// Cancel-and-replace is not enough for a mutation that has already left the device: cancelling
/// the task does not undo the request, so two opposite calls could still be in flight together and
/// the backend would keep whichever finished last. Chaining makes the last write come from the
/// newest intent instead — every pass starts only after the previous one is done and re-reads the
/// state it is about to push.
final class SerialRequestQueue<Key: Hashable> {
    private let queue = DispatchQueue(label: "SerialRequestQueue")
    private var tails = [Key: Task<Void, Never>]()
    private var outstanding = [Key: Int]()

    @discardableResult
    func enqueue(_ key: Key, _ operation: @escaping () async -> Void) -> Task<Void, Never> {
        queue.sync {
            let previous = tails[key]
            outstanding[key, default: 0] += 1
            let task = Task { [weak self] in
                await previous?.value
                await operation()
                self?.didFinish(key)
            }
            tails[key] = task
            return task
        }
    }

    /// A settled chain is dropped rather than kept as an empty tail: the keys are wallet ids, and
    /// a finished task per wallet would be retained for the life of the process. The count is what
    /// makes that safe — clearing the slot on its own would also drop a newer task that later
    /// callers are already chained behind, and they would then run alongside it.
    private func didFinish(_ key: Key) {
        queue.async { [weak self] in
            guard let self else { return }
            let remaining = (outstanding[key] ?? 1) - 1
            guard remaining > 0 else {
                outstanding[key] = nil
                tails[key] = nil
                return
            }
            outstanding[key] = remaining
        }
    }
}
