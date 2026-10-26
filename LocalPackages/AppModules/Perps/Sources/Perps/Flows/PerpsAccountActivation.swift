import Foundation

/// Runs one activation at a time and lets a finished one answer for the account until the
/// store reads the new key back: the refresh an activation starts lands later, and until
/// then the store still reports the key missing. Once the store has confirmed it, a key
/// missing again is a new activation.
@MainActor
final class PerpsAccountActivation {
    private var task: Task<Bool, Never>?
    private var isRunning = false
    private var confirmedWhileRunning = false

    func ensureReady(
        needsActivation: Bool,
        activate: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        if let task { return await task.value }
        guard needsActivation else { return true }
        let task = Task { await activate() }
        self.task = task
        isRunning = true
        confirmedWhileRunning = false
        let isReady = await task.value
        if self.task == task {
            isRunning = false
            if !isReady || confirmedWhileRunning { self.task = nil }
        }
        return isReady
    }

    func accountConfirmed() {
        if isRunning {
            confirmedWhileRunning = true
        } else {
            task = nil
        }
    }
}
