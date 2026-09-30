import Foundation

actor PerpsNonceCoordinator {
    struct Scope: Hashable, Sendable {
        let accountIndex: Int64
        let apiKeyIndex: Int32
        let chainId: Int32
    }

    private var cursors = [Scope: Int64]()

    func next(
        scope: Scope,
        fetch: @escaping @Sendable () async throws -> Int64
    ) async throws -> Int64 {
        if let cursor = cursors[scope] {
            let next = try increment(cursor)
            cursors[scope] = next
            return next
        }

        let remote = try await fetch()
        guard remote >= 0 else {
            throw PerpsTradingError.validation("nonce response is negative")
        }

        // A suspended actor call may interleave another initializer; allocate
        // after its cursor rather than returning a duplicate nonce.
        if let cursor = cursors[scope] {
            let next = try increment(cursor)
            cursors[scope] = next
            return next
        }
        cursors[scope] = remote
        return remote
    }

    func resync(
        scope: Scope,
        fetch: @escaping @Sendable () async throws -> Int64
    ) async throws {
        do {
            let remote = try await fetch()
            guard remote >= 0 else {
                throw PerpsTradingError.validation("nonce response is negative")
            }
            // `next` returns the anchor itself, so keep the previous value here.
            cursors[scope] = remote - 1
        } catch {
            // A failed refresh must not leave a stale cursor behind.
            cursors.removeValue(forKey: scope)
            throw error
        }
    }
}

private extension PerpsNonceCoordinator {
    func increment(_ cursor: Int64) throws -> Int64 {
        let (next, overflow) = cursor.addingReportingOverflow(1)
        guard !overflow else {
            throw PerpsTradingError.validation("nonce overflow")
        }
        return next
    }
}
