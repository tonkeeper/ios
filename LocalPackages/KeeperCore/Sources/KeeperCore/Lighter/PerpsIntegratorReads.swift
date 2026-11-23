import Foundation
import TKPerpsAPI

/// The integrator config, read when an order form opens. The approval check and the planner
/// take that read instead of asking again; a submit ends it, so the next trade reads anew.
/// `@unchecked Sendable`: `reads` is only touched under `lock`.
final class PerpsIntegratorReads: @unchecked Sendable {
    typealias Integrator = Components.Schemas.Integrator

    private let lock = NSLock()
    private var reads: [String: Task<Integrator, Error>] = [:]

    func refresh(walletId: String, read: @escaping @Sendable () async throws -> Integrator) {
        lock.withLock { reads[walletId] = Task { try await read() } }
    }

    func value(walletId: String, read: @escaping @Sendable () async throws -> Integrator) async throws -> Integrator {
        let task = lock.withLock { () -> Task<Integrator, Error> in
            if let task = reads[walletId] { return task }
            let task = Task { try await read() }
            reads[walletId] = task
            return task
        }
        do {
            return try await task.value
        } catch {
            lock.withLock {
                if reads[walletId] == task { reads[walletId] = nil }
            }
            throw error
        }
    }

    func invalidate(walletId: String) {
        lock.withLock { reads[walletId] = nil }
    }
}
