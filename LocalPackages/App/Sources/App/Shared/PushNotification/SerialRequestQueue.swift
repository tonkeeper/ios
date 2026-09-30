import Foundation

/// Serializes requests per key.
///
/// Cancel-and-replace is not enough for a mutation that has already left the device: cancelling
/// the task does not undo the request, so two opposite calls could still be in flight together and
/// the backend would keep whichever finished last. Chaining makes the last write come from the
/// newest intent instead — every pass starts only after the previous one is done and re-reads the
/// state it is about to push.
final class SerialRequestQueue<Key: Hashable> {
    private final class TailToken {}

    private struct Tail {
        let token: TailToken
        let task: Task<Void, Never>
    }

    private let queue = DispatchQueue(label: "SerialRequestQueue")
    private var tails = [Key: Tail]()

    @discardableResult
    func enqueue(_ key: Key, _ operation: @escaping () async -> Void) -> Task<Void, Never> {
        queue.sync {
            let previous = tails[key]?.task
            let token = TailToken()
            let task = Task { [weak self] in
                await previous?.value
                await operation()
                self?.didFinish(key, token: token)
            }
            tails[key] = Tail(token: token, task: task)
            return task
        }
    }

    private func didFinish(_ key: Key, token: TailToken) {
        queue.async { [weak self] in
            guard let self else { return }
            guard tails[key]?.token === token else { return }
            tails[key] = nil
        }
    }
}
