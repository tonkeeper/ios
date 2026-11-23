/// The user's answers within one confirm attempt: a review accepted in it is not asked about again
/// until its severity grows. Every attempt takes a fresh value.
public struct OperationConsent: Sendable {
    /// Never asks: whatever needs consent is refused.
    public static let refuse = OperationConsent { _ in false }

    private let ask: @Sendable (OperationReview) async -> Bool
    private let accepted = AcceptedReviews()

    public init(ask: @escaping @Sendable (OperationReview) async -> Bool) {
        self.ask = ask
    }

    /// Whether the reviewed operations may be signed.
    public func callAsFunction(_ review: OperationReview) async -> Bool {
        guard review.requiresConsent, let severity = review.severity else {
            return true
        }
        if await accepted.covers(review.id, at: severity) {
            return true
        }
        guard await ask(review) else {
            return false
        }
        await accepted.insert(review.id, at: severity)
        return true
    }
}

private actor AcceptedReviews {
    private var severities: [String: OperationFinding.Severity] = [:]

    func covers(_ id: String, at severity: OperationFinding.Severity) -> Bool {
        severities[id].map { $0 >= severity } ?? false
    }

    func insert(_ id: String, at severity: OperationFinding.Severity) {
        severities[id] = max(severities[id] ?? severity, severity)
    }
}
