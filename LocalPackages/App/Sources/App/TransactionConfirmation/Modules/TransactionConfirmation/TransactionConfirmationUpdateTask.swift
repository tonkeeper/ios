import Foundation

@MainActor
final class TransactionConfirmationUpdateTask {
    private var currentID: UUID?
    private var task: Task<Void, Never>?

    deinit { task?.cancel() }

    func replace(with operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        let id = UUID()
        currentID = id
        task = Task { [weak self] in
            defer { self?.finish(id) }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        currentID = nil
    }

    private func finish(_ id: UUID) {
        guard currentID == id else { return }
        task = nil
        currentID = nil
    }
}
