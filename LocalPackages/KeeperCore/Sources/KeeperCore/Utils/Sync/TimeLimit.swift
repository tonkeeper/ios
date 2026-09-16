import Foundation

/// Awaits `operation` for at most `timeLimit` and returns `nil` once the limit elapses.
/// The operation is not cancelled — the limit only stops the caller from blocking on it.
@discardableResult
func withTimeLimit<Success: Sendable>(
    _ timeLimit: TimeInterval,
    operation: @escaping @Sendable () async -> Success
) async -> Success? {
    let (stream, continuation) = AsyncStream<Success>.makeStream()

    Task {
        continuation.yield(await operation())
        continuation.finish()
    }
    let timeLimitTask = Task {
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, timeLimit) * 1_000_000_000))
        } catch {
            return
        }
        continuation.finish()
    }
    defer { timeLimitTask.cancel() }

    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}
