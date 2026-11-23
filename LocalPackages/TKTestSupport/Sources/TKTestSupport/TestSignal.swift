import Combine
import Foundation

/// Announces a change in a fake's recorded state, so `waitUntil(fake.changes)` re-checks its
/// condition on it. Sendable, so an actor fake can keep it as a `nonisolated let`.
public struct TestSignal: Publisher, Sendable {
    public typealias Output = Void
    public typealias Failure = Never

    private let name = Notification.Name("TKTestSupport.TestSignal.\(UUID().uuidString)")

    public init() {}

    public func send() {
        NotificationCenter.default.post(name: name, object: nil)
    }

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Void, S.Failure == Never {
        NotificationCenter.default.publisher(for: name).map { _ in }.receive(subscriber: subscriber)
    }
}
