import Foundation

actor PerpsExecutionLock {
    struct Scope: Hashable, Sendable {
        let accountIndex: Int64
        let apiKeyIndex: Int32
    }

    static let shared = PerpsExecutionLock()

    private var held = Set<Scope>()
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private var waiting = [Scope: [Waiter]]()

    private func acquire(_ scope: Scope) async -> Bool {
        guard held.contains(scope) else {
            held.insert(scope)
            return true
        }
        let id = UUID()
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    waiting[scope, default: []].append(Waiter(id: id, continuation: continuation))
                }
            } onCancel: {
                Task { await self.cancel(scope: scope, id: id) }
            }
            return true
        } catch {
            return false
        }
    }

    private func cancel(scope: Scope, id: UUID) {
        guard var queue = waiting[scope],
              let index = queue.firstIndex(where: { $0.id == id })
        else { return }
        let waiter = queue.remove(at: index)
        waiting[scope] = queue.isEmpty ? nil : queue
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func release(_ scope: Scope) {
        guard var queue = waiting[scope], !queue.isEmpty else {
            waiting[scope] = nil
            held.remove(scope)
            return
        }
        let next = queue.removeFirst()
        waiting[scope] = queue.isEmpty ? nil : queue
        next.continuation.resume()
    }

    nonisolated func withScope<T>(
        _ scope: Scope,
        _ body: () async throws -> T
    ) async throws -> T {
        guard await acquire(scope) else { throw CancellationError() }
        do {
            try Task.checkCancellation()
            let value = try await body()
            await release(scope)
            return value
        } catch {
            await release(scope)
            throw error
        }
    }
}
