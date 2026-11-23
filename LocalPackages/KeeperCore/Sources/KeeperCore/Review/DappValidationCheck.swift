import ChainKit
import Foundation
import OperationReviewModels

/// Kotlin's network lookups do not observe Swift cancellation. Stop waiting without treating an
/// unread operation as clean; a late result must not replace the review the user was asked about.
/// An error the check throws stays one: chain-kit reports a lookup that failed as a finding of its
/// own, so a check that throws could not read the operation at all, which a flow that asks never
/// signs.
struct DappValidationCheck: OperationCheck {
    static let defaultTimeLimit: TimeInterval = 5

    let check: any OperationCheck
    let timeLimit: TimeInterval

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        try Task.checkCancellation()
        let result = await withTimeLimit(timeLimit) {
            do {
                return try await Result<[OperationFinding], any Error>.success(check.findings(of: signable))
            } catch {
                return .failure(error)
            }
        }
        try Task.checkCancellation()
        if let result {
            return try result.get()
        }
        return try ChainKitValidationCheck.findings(
            [ValidationError.Unknown(cause: nil)],
            of: signable,
            intent: ChainKitValidationCheck.intent(of: signable)
        ).map {
            OperationFinding(
                id: $0.id, kind: $0.kind, severity: $0.severity, title: $0.title,
                failure: "chain-kit validation exceeded \(timeLimit) s"
            )
        }
    }
}
