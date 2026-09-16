import Foundation

/// Errors a repeat can plausibly clear. Only the transport class qualifies: a status the backend
/// chose repeats identically, and a server-side fault is left to the next trigger — foreground or
/// cold start — rather than to a tight loop.
protocol MultichainTransientError: Error {
    var isTransient: Bool { get }
}

extension DeviceAuthError: MultichainTransientError {
    var isTransient: Bool {
        guard case .connectionError = self else { return false }
        return true
    }
}

extension MultichainServiceError: MultichainTransientError {
    var isTransient: Bool {
        guard case .connectionError = self else { return false }
        return true
    }
}

/// Repeats the whole sequence rather than a single request: every multichain call worth retrying
/// spends a single-use challenge, so only a fresh pass can succeed — and `HTTPBody` is single-shot,
/// which is why this cannot live in a client middleware.
enum MultichainRetry {
    typealias Sleep = @Sendable (TimeInterval) async -> Void

    static let defaultAttempts = 3
    static let maxDelay: TimeInterval = 8

    static let defaultSleep: Sleep = { seconds in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    static func delay(afterAttempt attempt: Int) -> TimeInterval {
        min(pow(2, Double(max(attempt, 1) - 1)), maxDelay)
    }

    /// A business call establishes the device session on its way out, and that ladder repeats too.
    /// Nesting the two would multiply the attempt counts and their pauses, so the outermost `run`
    /// owns the budget: it re-runs the sequence from the top, which covers a failed session anyway.
    @TaskLocal private static var isNested = false

    /// `owningBudget` opts out of that deference. It exists for work that is shared rather than
    /// nested: an unstructured `Task` inherits task locals, so a task other callers join would
    /// otherwise take its budget from whichever caller happened to create it, and a joiner that is
    /// not retrying at all would silently get a single attempt.
    static func run<T, E: MultichainTransientError>(
        attempts: Int = defaultAttempts,
        owningBudget: Bool = false,
        sleep: Sleep = defaultSleep,
        _ operation: () async throws(E) -> T
    ) async throws(E) -> T {
        guard owningBudget || !isNested else {
            return try await operation()
        }
        var attempt = 0
        while true {
            attempt += 1
            switch await attempted(operation) {
            case let .success(value):
                return value
            case let .failure(error):
                guard error.isTransient, attempt < attempts, !Task.isCancelled else {
                    throw error
                }
                await sleep(delay(afterAttempt: attempt))
                // The pause is the only place a cancellation can land unnoticed; the operation
                // itself reports it as an error.
                guard !Task.isCancelled else { throw error }
            }
        }
    }

    /// `withValue` is `rethrows`, which erases a typed `throws(E)` back to `any Error`; carrying the
    /// outcome as a `Result` keeps the closure non-throwing and the error type intact.
    private static func attempted<T, E: MultichainTransientError>(
        _ operation: () async throws(E) -> T
    ) async -> Result<T, E> {
        await $isNested.withValue(true) { () async -> Result<T, E> in
            do throws(E) {
                return try .success(await operation())
            } catch {
                return .failure(error)
            }
        }
    }
}
