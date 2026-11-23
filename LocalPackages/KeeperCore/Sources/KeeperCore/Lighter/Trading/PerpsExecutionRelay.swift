import ChainKit
import Foundation
import PerpsModels
import TKLogging

final class PerpsExecutionRelay: NSObject, PerpsExecutionDelegate {
    private let lane: PerpsSubmitLane
    private let logContext = PerpsOperationLog.context
    private let persistState: (PerpsSignedStep, PerpsPendingStepState) async throws -> Void
    /// The execution reports a refusal by kind only, so the one that asks for a new
    /// integrator approval is kept here for the caller.
    private(set) var integratorNotApproved = false
    private(set) var sendRefused = false
    private var refusedSteps = Set<String>()
    private var nonceToReuse: Int64?

    init(
        lane: PerpsSubmitLane,
        persistState: @escaping (PerpsSignedStep, PerpsPendingStepState) async throws -> Void
    ) {
        self.lane = lane
        self.persistState = persistState
    }

    func currentTimeUnixMs(completionHandler: @escaping (KotlinLong?, Error?) -> Void) {
        completionHandler(KotlinLong(value: PerpsPlannerMapping.nowUnixMs()), nil)
    }

    func nextNonce(
        scope: PerpsScope,
        completionHandler: @escaping (PerpsExecutionNonce?, Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "nextNonce", "wallet_id": scope.walletId, "account_index": String(scope.accountIndex)]) { _, new in new }) {
                do {
                    let nonce = try await lane.nextNonce(walletId: scope.walletId)
                    completionHandler(PerpsExecutionNonce(value: nonce), nil)
                } catch {
                    completionHandler(nil, executionNSError(error))
                }
            }
        }
    }

    func resyncNonce(
        scope: PerpsScope,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "resyncNonce", "wallet_id": scope.walletId, "account_index": String(scope.accountIndex)]) { _, new in new }) {
                do {
                    if let nonce = nonceToReuse {
                        nonceToReuse = nil
                        try await lane.reuseNonce(nonce)
                        PerpsOperationLog.event("nonce", outcome: "reused", source: "client", fields: ["nonce": String(nonce)])
                    } else {
                        try await lane.resyncNonce(walletId: scope.walletId)
                    }
                    completionHandler(nil)
                } catch {
                    completionHandler(executionNSError(error))
                }
            }
        }
    }

    func persistSigned(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "persistSigned", "step_id": step.stepId, "attempt_id": step.attemptId, "nonce": String(step.nonce), "tx_type": String(step.txType), "l2_tx_hash": step.txHash]) { _, new in new }) {
                do {
                    try await persistState(step, .signed)
                    completionHandler(nil)
                } catch {
                    completionHandler(executionNSError(error))
                }
            }
        }
    }

    func markStepSending(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "markStepSending", "step_id": step.stepId, "attempt_id": step.attemptId, "nonce": String(step.nonce), "tx_type": String(step.txType), "l2_tx_hash": step.txHash]) { _, new in new }) {
                do {
                    try await persistState(step, .sending)
                    completionHandler(nil)
                } catch {
                    completionHandler(executionNSError(error))
                }
            }
        }
    }

    func markStepAccepted(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "markStepAccepted", "step_id": step.stepId, "attempt_id": step.attemptId, "nonce": String(step.nonce), "tx_type": String(step.txType), "l2_tx_hash": step.txHash]) { _, new in new }) {
                do {
                    try await persistState(step, .accepted)
                    completionHandler(nil)
                } catch {
                    completionHandler(executionNSError(error))
                }
            }
        }
    }

    func markStepUnknown(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "markStepUnknown", "step_id": step.stepId, "attempt_id": step.attemptId, "nonce": String(step.nonce), "tx_type": String(step.txType), "l2_tx_hash": step.txHash]) { _, new in new }) {
                do {
                    try await persistState(step, .unknown)
                    completionHandler(nil)
                } catch {
                    completionHandler(executionNSError(error))
                }
            }
        }
    }

    func submit(
        step: PerpsSignedStep,
        completionHandler: @escaping (PerpsSubmissionOutcome?, Error?) -> Void
    ) {
        Task {
            await PerpsOperationLog.withContext(fields: logContext.merging(["delegate_stage": "submit", "step_id": step.stepId, "attempt_id": step.attemptId, "nonce": String(step.nonce), "tx_type": String(step.txType), "l2_tx_hash": step.txHash]) { _, new in new }) {
                do {
                    try await lane.send(
                        walletId: step.scope.walletId,
                        txType: step.txType,
                        txInfo: step.txInfo,
                        txHash: step.txHash,
                        nonce: step.nonce
                    )
                    completionHandler(.accepted, nil)
                } catch let error as PerpsAPIError where error.isResignRequired {
                    PerpsOperationLog.event("nonce", outcome: "resign_required", source: "lighter", error: error)
                    guard refusedSteps.contains(step.stepId) else {
                        refusedSteps.insert(step.stepId)
                        nonceToReuse = step.nonce
                        completionHandler(.resignrequired, nil)
                        return
                    }
                    await lane.forgetNonce()
                    do {
                        try await persistState(step, .unknown)
                    } catch {
                        PerpsOperationLog.event("journal", outcome: "failed", error: error)
                    }
                    completionHandler(nil, executionNSError(PerpsTradingError.submitUnknown))
                } catch {
                    if (error as? PerpsAPIError)?.isIntegratorNotApproved == true {
                        integratorNotApproved = true
                    }
                    let mapped = PerpsTradingErrorMapper.map(error)
                    let isRetry = refusedSteps.contains(step.stepId)
                    if Self.leavesNonceUnconsumed(error), !isRetry {
                        sendRefused = true
                        await lane.returnUnconsumedNonce(step.nonce)
                    } else if Self.isAmbiguous(mapped) {
                        do {
                            try await persistState(step, .unknown)
                        } catch {
                            PerpsOperationLog.event("journal", outcome: "failed", error: error)
                        }
                    }
                    if isRetry, Self.leavesNonceUnconsumed(error) {
                        await lane.forgetNonce()
                    }
                    completionHandler(nil, executionNSError(error))
                }
            }
        }
    }

    static func leavesNonceUnconsumed(_ error: Error) -> Bool {
        switch error as? PerpsAPIError {
        case let .badStatus(failure):
            return (failure.code != nil && (400 ..< 500).contains(failure.httpStatus))
                || failure.code == "region_check_unavailable"
        case .unauthorized:
            return true
        default:
            return false
        }
    }

    static func isAmbiguous(_ error: PerpsTradingError) -> Bool {
        switch error {
        case .offline, .timeout, .serverUnavailable, .protocolFailure, .unknown:
            return true
        case .rateLimited, .serverRejected, .authExpired, .credentialsRevoked,
             .activationRequired, .activationCanceled, .regionUnavailable, .tradingUnavailable, .validation,
             .invalidAutoClose, .invalidAmount, .conflictingPosition, .exceedsPosition, .nothingToChange,
             .insufficientBalance, .insufficientLiquidity, .slippageExceeded, .positionNotFound, .orderNotFound,
             .orderFilledBeforeCancel, .immediateLiquidationRisk, .operationInProgress, .stalePreparedTransaction,
             .deviceClockSkew, .submitUnknown:
            return false
        }
    }
}

extension PerpsExecutionRelay {
    static func normalizedHash(_ hash: String) -> String {
        let value = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
    }
}

private extension PerpsExecutionRelay {
    func executionNSError(_ error: Error) -> NSError {
        let mapped = PerpsTradingErrorMapper.map(error)
        PerpsOperationLog.event("execution_delegate", outcome: "failed", source: mapped.operationLogSource, error: error, fields: mapped.operationLogFields)
        let execution = PerpsExecutionException(
            kind: Self.executionErrorKind(mapped),
            message: String(describing: mapped)
        )
        return NSError(
            domain: "ChainKitPerpsExecution",
            code: 1,
            userInfo: [
                "KotlinException": execution,
                NSLocalizedDescriptionKey: execution.message ?? "execution failed",
            ]
        )
    }

    static func executionErrorKind(_ error: PerpsTradingError) -> PerpsExecutionErrorKind {
        switch error {
        case .offline: return .offline
        case .timeout: return .timeout
        case .rateLimited: return .ratelimited
        case .serverUnavailable: return .serverunavailable
        case .serverRejected: return .serverrejected
        case .authExpired: return .authexpired
        case .credentialsRevoked: return .credentialsrevoked
        case .activationRequired: return .activationrequired
        case .activationCanceled: return .activationcanceled
        case .regionUnavailable: return .regionunavailable
        // The execution kinds carry no "market not tradable", and borrowing the region one
        // would write the same false claim into the journal.
        case .tradingUnavailable: return .validation
        case .validation, .invalidAutoClose, .invalidAmount, .conflictingPosition, .exceedsPosition: return .validation
        case .nothingToChange: return .nothingtochange
        case .insufficientBalance: return .insufficientbalance
        case .insufficientLiquidity, .slippageExceeded: return .insufficientliquidity
        case .positionNotFound, .orderNotFound, .orderFilledBeforeCancel: return .positionnotfound
        case .immediateLiquidationRisk: return .immediateliquidationrisk
        case .protocolFailure: return .protocolfailure
        case .operationInProgress: return .operationinprogress
        case .stalePreparedTransaction: return .stalepreparedtransaction
        case .deviceClockSkew: return .validation
        case .submitUnknown: return .submitunknown
        case .unknown: return .unknown
        }
    }
}
