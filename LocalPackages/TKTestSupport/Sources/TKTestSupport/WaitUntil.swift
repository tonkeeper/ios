import Combine
import XCTest

/// Waits until `condition` holds, re-checking it after each value `changes` publishes — never on a timer.
/// `timeout` only bounds a wait that fails.
///
/// The condition runs in the caller's isolation, so a test off the main actor never waits for it.
/// A publisher that fires before its change lands needs the change's isolation: see the `ObservableObject` overload.
public func waitUntil<Changes: Publisher>(
    _ changes: Changes,
    timeout: TimeInterval = 5,
    isolation _: isolated (any Actor)? = #isolation,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () async -> Bool
) async where Changes.Failure == Never {
    let (wakeUps, wake) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let subscription = changes.sink { _ in wake.yield() }
    let deadline = Task {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        wake.finish()
    }
    defer {
        subscription.cancel()
        deadline.cancel()
    }
    if await condition() { return }
    for await _ in wakeUps {
        if await condition() { return }
    }
    guard !Task.isCancelled else { return }
    XCTFail("Condition not met within \(timeout) s", file: file, line: line)
}

/// Waits until `condition` holds, re-checking it after each change `object` announces.
/// `objectWillChange` fires before the change lands; the re-check runs after the main-actor job that makes it.
@MainActor
public func waitUntil<Object: ObservableObject>(
    _ object: Object,
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () async -> Bool
) async {
    await waitUntil(object.objectWillChange, timeout: timeout, file: file, line: line, condition)
}
