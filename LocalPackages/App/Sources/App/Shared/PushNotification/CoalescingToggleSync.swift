import Foundation

/// Serializes optimistic toggles per key and rolls back rejected values.
@MainActor
final class CoalescingToggleSync<Key: Hashable> {
    private var intents = [Key: Bool]()
    private var accepted = [Key: Bool]()
    private var workers = [Key: Task<Void, Never>]()
    private var applies = [Key: (version: Int, task: Task<Void, Never>)]()

    nonisolated init() {}

    /// `currentIsOn` seeds each burst; `sync` receives the desired and last accepted values.
    /// `onRejected` reconciles the backend after rollback.
    @discardableResult
    func toggle(
        _ isOn: Bool,
        key: Key,
        currentIsOn: Bool,
        apply: @escaping @MainActor (Bool) async -> Void,
        sync: @escaping @MainActor (Bool, Bool) async -> Bool,
        onRejected: @escaping @MainActor () async -> Void = {}
    ) -> Task<Void, Never> {
        if workers[key] == nil {
            accepted[key] = currentIsOn
        }
        intents[key] = isOn
        enqueueApply(isOn, key: key, apply: apply)
        if let worker = workers[key] {
            return worker
        }
        let worker = Task { await self.drain(key: key, apply: apply, sync: sync, onRejected: onRejected) }
        workers[key] = worker
        return worker
    }

    private func drain(
        key: Key,
        apply: @escaping @MainActor (Bool) async -> Void,
        sync: @MainActor (Bool, Bool) async -> Bool,
        onRejected: @MainActor () async -> Void
    ) async {
        while true {
            if let pending = applies[key] {
                await pending.task.value
                if applies[key]?.version != pending.version { continue }
            }
            guard let target = intents[key], let base = accepted[key], target != base else { break }
            if await sync(target, base) {
                accepted[key] = target
            } else if intents[key] == target {
                intents[key] = base
                let rollback = enqueueApply(base, key: key, apply: apply)
                await rollback.value
                if intents[key] == base { await onRejected() }
            }
        }
        // The next burst must read the current toggle, which may have changed elsewhere.
        workers[key] = nil
        intents[key] = nil
        accepted[key] = nil
        applies[key] = nil
    }

    @discardableResult
    private func enqueueApply(_ value: Bool, key: Key, apply: @escaping @MainActor (Bool) async -> Void) -> Task<Void, Never> {
        let previous = applies[key]
        let task = Task {
            await previous?.task.value
            await apply(value)
        }
        applies[key] = (version: (previous?.version ?? 0) + 1, task: task)
        return task
    }
}
