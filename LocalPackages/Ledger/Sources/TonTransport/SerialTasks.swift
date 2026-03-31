import Foundation

actor SerialTasks<T: Sendable> {
    private var previousTask: Task<T, any Error>?

    func add(block: @Sendable @escaping () async throws -> T) async throws -> T {
        let task = Task { [previousTask] in
            let _ = await previousTask?.result
            return try await block()
        }
        previousTask = task
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
