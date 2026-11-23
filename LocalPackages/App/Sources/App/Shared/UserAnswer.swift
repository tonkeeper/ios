/// The yes or no a question waits for. A reply released without an answer — nobody to ask, or an
/// alert torn down without a tap — answers no.
final class UserAnswer {
    private var continuation: CheckedContinuation<Bool, Never>?

    private init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    deinit {
        continuation?.resume(returning: false)
    }

    /// Only the first reply counts.
    @MainActor
    static func ask(_ question: (_ reply: @escaping (Bool) -> Void) -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            let answer = UserAnswer(continuation)
            question { answer.give($0) }
        }
    }

    private func give(_ value: Bool) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
