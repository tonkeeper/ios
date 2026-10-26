import Foundation

/// One refresh at a time: a newer request cancels the one before it and starts only once that one
/// has returned, so the ActivityKit writes of two refreshes never interleave.
@available(iOS 16.2, *)
@MainActor
final class TransactionLiveActivityRefreshQueue {
    private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    func schedule(
        after delay: TimeInterval,
        onFinish: @escaping @MainActor () -> Void = {},
        _ operation: @escaping @MainActor (TransactionLiveActivityRefreshFinalization) async -> Void
    ) {
        let previous = task
        previous?.cancel()
        task = Task {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            await previous?.value
            guard !Task.isCancelled else { return }
            let finalization = TransactionLiveActivityRefreshFinalization()
            await operation(finalization)
            await finalization.finish()
            onFinish()
        }
    }

    func cancel() {
        task?.cancel()
    }

    func waitForCurrent() async {
        await task?.value
    }
}

@available(iOS 16.2, *)
@MainActor
final class TransactionLiveActivityRefreshFinalization {
    private var pending: (@MainActor () async -> Void)?

    func set(_ operation: @escaping @MainActor () async -> Void) {
        pending = operation
    }

    func clear() {
        pending = nil
    }

    func finish() async {
        let operation = pending
        pending = nil
        await operation?()
    }
}
