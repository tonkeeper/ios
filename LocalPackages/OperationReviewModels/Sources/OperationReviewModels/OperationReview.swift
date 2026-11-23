/// What the checks found in the operations a flow is about to sign.
public struct OperationReview: Sendable, Hashable {
    /// The same for the same operations, account and intent: a rebuild that changes none of them is
    /// the same review.
    public let id: String
    public let findings: [OperationFinding]

    public init(id: String, findings: [OperationFinding]) {
        self.id = id
        self.findings = findings
    }

    public var severity: OperationFinding.Severity? {
        findings.map(\.severity).max()
    }

    /// An info finding is never shown; anything above it is signed only with the user's consent.
    public var requiresConsent: Bool {
        findings.contains { $0.severity > .info }
    }
}

public struct OperationFinding: Sendable, Hashable, Identifiable {
    public enum Severity: Sendable, Hashable, Comparable {
        case info, warning, danger
    }

    public let id: String
    /// The check's own category, e.g. a ChainKit validation error class.
    public let kind: String
    public let severity: Severity
    public let title: String
    public let details: String?
    /// What the finding is about, e.g. an address, for the user to read in full.
    public let subject: String?
    /// What kept the check from reading the operation, for a finding that it read nothing: logged as
    /// the failure it is, never shown.
    public let failure: String?

    public init(
        id: String,
        kind: String,
        severity: Severity,
        title: String,
        details: String? = nil,
        subject: String? = nil,
        failure: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.details = details
        self.subject = subject
        self.failure = failure
    }
}
