import ChainKit
import CryptoKit
import Foundation
import OperationReviewModels
import TKLogging

/// A check the gate runs on every operation a flow is about to sign.
protocol OperationCheck: Sendable {
    /// Throws when it cannot check the operation: one it could not check never passes as clean. A
    /// finding's id tells it apart where it is shown, so it must not repeat within the review.
    func findings(of signable: SignableOperation) async throws -> [OperationFinding]
}

/// Whether the user is asked about what the checks find, or the findings are only logged while the
/// checks prove themselves on a flow.
enum OperationPresentation {
    case ask
    case logOnly
}

enum OperationRefusal: Error, Equatable {
    /// The user said no, or the flow was abandoned.
    case declined
    /// What is signed could not be built or checked, and an operation no check has read is not signed.
    case unreviewable(reason: String)
}

/// The step every flow takes before it signs: what it is about to sign is built, checked and, when a
/// finding requires it, put to the user. A flow that is only logged does not wait for the checks. What
/// the gate logs names the flow's call, not the gate.
struct OperationGate: Sendable {
    /// Read at every review. With none, nothing is built and everything passes.
    let checks: @Sendable () -> [any OperationCheck]

    /// What tints the confirm control before the user confirms. Never asks: a review that could not
    /// be made, or one that is only logged, leaves the control as it is.
    func preview(
        _ presentation: OperationPresentation,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        _ build: () async throws -> [SignableOperation]
    ) async -> OperationReview? {
        let checks = self.checks()
        guard !checks.isEmpty else {
            return nil
        }
        let caller = Caller(file: file, function: function, line: line)
        switch presentation {
        case .ask:
            guard case let .success(review) = await Self.review(by: checks, for: caller, build) else {
                return nil
            }
            return review
        case .logOnly:
            await Self.shadow(by: checks, for: caller, build)
            return nil
        }
    }

    /// Runs on what goes to the signer, after the last step that can change it. A flow that is
    /// only logged is never stopped, nor kept waiting for its checks.
    func clear(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        _ build: () async throws -> [SignableOperation]
    ) async throws(OperationRefusal) {
        let checks = self.checks()
        guard !checks.isEmpty else {
            return
        }
        let caller = Caller(file: file, function: function, line: line)
        switch presentation {
        case .logOnly:
            await Self.shadow(by: checks, for: caller, build)
        case .ask:
            let outcome = await Self.review(by: checks, for: caller, build)
            // An abandoned flow is declined whatever its review came to.
            guard !Task.isCancelled else {
                throw .declined
            }
            switch outcome {
            case let .failure(error):
                throw .unreviewable(reason: error.logDescription)
            case let .success(review):
                guard await consent(review), !Task.isCancelled else {
                    throw .declined
                }
            }
        }
    }
}

private extension OperationGate {
    /// Where the flow called the gate.
    struct Caller {
        let file: StaticString
        let function: StaticString
        let line: UInt
    }

    static func review(
        by checks: [any OperationCheck],
        for caller: Caller,
        _ build: () async throws -> [SignableOperation]
    ) async -> Result<OperationReview, any Error> {
        switch await built(for: caller, build) {
        case let .success(signables):
            return await checked(signables, by: checks, for: caller)
        case let .failure(error):
            return .failure(error)
        }
    }

    /// A review that is only logged: what is signed is built as the flow goes, and checked in a task
    /// of its own that the flow does not wait for. chain-kit may look an account up on the network to
    /// check it, and nothing cancels that lookup.
    static func shadow(
        by checks: [any OperationCheck],
        for caller: Caller,
        _ build: () async throws -> [SignableOperation]
    ) async {
        guard case let .success(signables) = await built(for: caller, build) else {
            return
        }
        Task {
            if case let .success(review) = await checked(signables, by: checks, for: caller) {
                logUnasked(review, of: signables, for: caller)
            }
        }
    }

    static func built(
        for caller: Caller,
        _ build: () async throws -> [SignableOperation]
    ) async -> Result<[SignableOperation], any Error> {
        do {
            return try await .success(build())
        } catch {
            logFailure("Operation review could not build what is signed", error: error, signables: [], for: caller)
            return .failure(error)
        }
    }

    static func checked(
        _ signables: [SignableOperation],
        by checks: [any OperationCheck],
        for caller: Caller
    ) async -> Result<OperationReview, any Error> {
        var findings = [OperationFinding]()
        for signable in signables {
            for check in checks {
                do {
                    let found = try await check.findings(of: signable)
                    logUnread(found, of: signable, for: caller)
                    findings += found
                } catch {
                    logFailure("Operation review could not check what is signed", error: error, signables: signables, check: check, for: caller)
                    return .failure(error)
                }
            }
        }
        do {
            return try .success(OperationReview(id: id(of: signables), findings: findings))
        } catch {
            logFailure("Operation review could not check what is signed", error: error, signables: signables, for: caller)
            return .failure(error)
        }
    }

    /// The same for the same operations, accounts and intents, so an unchanged rebuild is the same
    /// review.
    static func id(of signables: [SignableOperation]) throws -> String {
        let identity = try signables.map { signable throws -> [[String]] in
            let account = signable.account
            let intent = signable.intent
            let spends = intent.spends?.map { [$0.assetId, String($0.decimals), $0.amount.description] }
            let fee = intent.relayerFee.map { [["relayer fee", $0.assetId, String($0.decimals), $0.amount.description]] }
            return try [
                [signable.operation.id, signable.operation.meta],
                [
                    account.chain.id,
                    account.addressDisplay,
                    account.address.type.id,
                    identity(of: account.derivation),
                    account.publicKey?.defaultHex ?? "",
                    account.asset.id,
                ],
                [intent.isDapp ? "dapp" : "wallet", intent.recipient ?? ""],
            ] + (spends ?? [["unbounded"]]) + (fee ?? [])
        }
        return try Data(SHA256.hash(data: JSONEncoder().encode(identity))).hexString()
    }

    static func identity(of derivation: any Derivation) throws -> String {
        switch derivation {
        case is DerivationDefaultPath:
            return "default"
        case let path as DerivationPath:
            return "path:" + path.value
        case let binary as DerivationBinary:
            return "binary:" + binary.value.asData.base64EncodedString()
        default:
            throw ChainKitOperationError.unsupportedAccount("derivation \(derivation)")
        }
    }

    static func logFailure(
        _ message: String,
        error: any Error,
        signables: [SignableOperation],
        check: (any OperationCheck)? = nil,
        for caller: Caller
    ) {
        var info = context(of: signables)
        info["check"] = check.map { "\(type(of: $0))" }
        // Crashlytics reports `.error`, and a review an abandoned flow cut short is no failure.
        Log.chainKit.log(
            Task.isCancelled ? .info : .error,
            message,
            file: caller.file,
            function: caller.function,
            line: caller.line,
            error: error,
            extraInfo: info
        )
    }

    /// Findings that say a check read nothing. A flow of the wallet's own shows them as info, so the
    /// log is all that tells a check that failed from a clean operation.
    static func logUnread(_ findings: [OperationFinding], of signable: SignableOperation, for caller: Caller) {
        for case let failure? in findings.map(\.failure) {
            Log.chainKit.log(
                .error,
                "Operation validation read nothing",
                file: caller.file,
                function: caller.function,
                line: caller.line,
                extraInfo: ["operation": signable.operation.id, "asset": signable.account.asset.id, "finding": failure]
            )
        }
    }

    /// Findings that would have asked, in a flow the checks only shadow.
    static func logUnasked(_ review: OperationReview, of signables: [SignableOperation], for caller: Caller) {
        let unasked = review.findings.filter { $0.severity > .info }
        guard !unasked.isEmpty else {
            return
        }
        var info = context(of: signables)
        info["findings"] = unasked.map { "\($0.severity):\($0.kind)" }.joined(separator: ",")
        Log.chainKit.e(
            "Operation review found what would ask in a flow it only logs",
            file: caller.file,
            function: caller.function,
            line: caller.line,
            extraInfo: info
        )
    }

    /// Every copy of a ChainKit send is the operation `transfer`: the assets, their ids led by the
    /// chain's, tell one chain's sends from another's.
    static func context(of signables: [SignableOperation]) -> [String: String] {
        [
            "operations": signables.map(\.operation.id).joined(separator: ","),
            "assets": signables.map(\.account.asset.id).joined(separator: ","),
            "fidelity": signables.map(\.fidelity.rawValue).joined(separator: ","),
        ]
    }
}
