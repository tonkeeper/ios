import Foundation

@MainActor
final class BatteryRechargePickerRequest {
    private var task: Task<Void, Never>?
    private var requestID: UUID?
    private var onLoadingChange: ((Bool) -> Void)?

    @discardableResult
    func load<Value>(onLoadingChange: @escaping (Bool) -> Void, load: @escaping () async -> Value, completion: @escaping (Value) -> Void) -> Task<Void, Never>? {
        guard task == nil else { return nil }
        let id = UUID()
        requestID = id
        self.onLoadingChange = onLoadingChange
        let task = Task { @MainActor [weak self] in
            defer { self?.finish(id: id) }
            guard !Task.isCancelled else { return }
            let value = await load()
            guard !Task.isCancelled, self?.requestID == id else { return }
            completion(value)
        }
        self.task = task
        onLoadingChange(true)
        return task
    }

    func cancel() {
        guard let requestID else { return }
        let task = task
        finish(id: requestID)
        task?.cancel()
    }

    private func finish(id: UUID) {
        guard requestID == id else { return }
        task = nil
        requestID = nil
        let onLoadingChange = onLoadingChange
        self.onLoadingChange = nil
        onLoadingChange?(false)
    }

    deinit {
        task?.cancel()
    }
}
