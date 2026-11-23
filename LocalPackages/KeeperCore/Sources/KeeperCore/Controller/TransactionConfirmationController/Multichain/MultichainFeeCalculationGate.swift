import Foundation

/// A cancelled calculation can still finish a non-cooperative engine call. Keep its writes ahead
/// of the next calculation's preference reset, including across suspension points.
actor MultichainFeeCalculationGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let onWait: @Sendable () -> Void

    init(onWait: @escaping @Sendable () -> Void = {}) {
        self.onWait = onWait
    }

    private var isOccupied = false
    private var waiters = [Waiter]()

    var waitingCount: Int {
        waiters.count
    }

    func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        guard isOccupied else {
            isOccupied = true
            return true
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                waiters.append(Waiter(id: id, continuation: continuation))
                onWait()
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isOccupied = false
            return
        }
        waiters.removeFirst().continuation.resume(returning: true)
    }

    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(returning: false)
    }
}
