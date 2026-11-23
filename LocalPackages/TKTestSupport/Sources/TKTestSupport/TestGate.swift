import Foundation

/// Holds the fakes that wait on it until the test opens it. Replaces a fake's real delay
/// (`Task.sleep`) when a test needs work to stay in flight, and an injected `sleep` when it needs
/// to control time.
///
/// A cancelled waiter throws `CancellationError`, as `Task.sleep` does.
public actor TestGate {
    private var isOpen = false
    private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]

    public init() {}

    public func wait() async throws {
        guard !isOpen else { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                register(continuation, id: id)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    private func register(_ continuation: CheckedContinuation<Void, any Error>, id: UUID) {
        if Task.isCancelled {
            continuation.resume(throwing: CancellationError())
        } else if isOpen {
            continuation.resume()
        } else {
            waiters[id] = continuation
        }
    }

    public func open() {
        isOpen = true
        let opened = waiters.values
        waiters.removeAll()
        opened.forEach { $0.resume() }
    }

    private func cancel(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
}
