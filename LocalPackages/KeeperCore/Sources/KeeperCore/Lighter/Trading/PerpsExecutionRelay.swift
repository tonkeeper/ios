import ChainKit
import Foundation

final class PerpsExecutionRelay: NSObject, PerpsExecutionDelegate {
    private let api: PerpsAPI
    private let nonceCoordinator: PerpsNonceCoordinator
    private let persistSignedStep: ((PerpsSignedStep) async throws -> Void)?
    private let persistState: ((PerpsSignedStep, PerpsPendingStepState) async throws -> Void)?

    init(
        api: PerpsAPI,
        nonceCoordinator: PerpsNonceCoordinator,
        persist: @escaping (PerpsSignedStep) async throws -> Void
    ) {
        self.api = api
        self.nonceCoordinator = nonceCoordinator
        persistSignedStep = persist
        persistState = nil
    }

    init(
        api: PerpsAPI,
        nonceCoordinator: PerpsNonceCoordinator,
        persistState: @escaping (PerpsSignedStep, PerpsPendingStepState) async throws -> Void
    ) {
        self.api = api
        self.nonceCoordinator = nonceCoordinator
        persistSignedStep = nil
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
            do {
                let nonce = try await nonceCoordinator.next(
                    scope: .init(
                        accountIndex: scope.accountIndex,
                        apiKeyIndex: scope.apiKeyIndex,
                        chainId: scope.chainId
                    )
                ) { [api] in
                    try await api.nextNonce(
                        walletId: scope.walletId,
                        apiKeyIndex: Int(scope.apiKeyIndex)
                    ).nonce
                }
                completionHandler(PerpsExecutionNonce(value: nonce), nil)
            } catch {
                completionHandler(nil, executionNSError(error))
            }
        }
    }

    func resyncNonce(
        scope: PerpsScope,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await nonceCoordinator.resync(
                    scope: .init(
                        accountIndex: scope.accountIndex,
                        apiKeyIndex: scope.apiKeyIndex,
                        chainId: scope.chainId
                    )
                ) { [api] in
                    try await api.nextNonce(
                        walletId: scope.walletId,
                        apiKeyIndex: Int(scope.apiKeyIndex)
                    ).nonce
                }
                completionHandler(nil)
            } catch {
                completionHandler(executionNSError(error))
            }
        }
    }

    func persistSigned(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                if let persistSignedStep {
                    try await persistSignedStep(step)
                } else if let persistState {
                    try await persistState(step, .signed)
                }
                completionHandler(nil)
            } catch {
                completionHandler(executionNSError(error))
            }
        }
    }

    func markStepSending(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                if let persistState {
                    try await persistState(step, .sending)
                }
                completionHandler(nil)
            } catch {
                completionHandler(executionNSError(error))
            }
        }
    }

    func markStepAccepted(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                if let persistState {
                    try await persistState(step, .accepted)
                }
                completionHandler(nil)
            } catch {
                completionHandler(executionNSError(error))
            }
        }
    }

    func markStepUnknown(
        step: PerpsSignedStep,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                if let persistState {
                    try await persistState(step, .unknown)
                }
                completionHandler(nil)
            } catch {
                completionHandler(executionNSError(error))
            }
        }
    }

    func submit(
        step: PerpsSignedStep,
        completionHandler: @escaping (PerpsSubmissionOutcome?, Error?) -> Void
    ) {
        Task {
            do {
                try await submit(step: step)
                completionHandler(.accepted, nil)
            } catch let error as PerpsAPIError where error.isResignRequired {
                completionHandler(.resignrequired, nil)
            } catch {
                let mapped = PerpsTradingErrorMapper.map(error)
                if Self.isAmbiguous(mapped), let persistState {
                    try? await persistState(step, .unknown)
                }
                completionHandler(nil, executionNSError(error))
            }
        }
    }

    func submitPersisted(
        walletId: String,
        txType: Int32,
        txInfo: String,
        expectedTxHash: String
    ) async throws {
        let response = try await api.sendTransactions(
            walletId: walletId,
            transactions: [.init(tx_type: txType, tx_info: txInfo)]
        )
        let responseHash = Self.normalizedHash(response.transactions.first?.tx_hash ?? "")
        let expectedHash = Self.normalizedHash(expectedTxHash)
        guard response.transactions.count == 1,
              response.transactions[0].tx_type == txType,
              !responseHash.isEmpty,
              !expectedHash.isEmpty,
              responseHash == expectedHash
        else {
            throw PerpsTradingError.protocolFailure("send response does not match the submitted transaction")
        }
    }
}

private extension PerpsExecutionRelay {
    func submit(step: PerpsSignedStep) async throws {
        let response = try await api.sendTransactions(
            walletId: step.scope.walletId,
            transactions: [.init(tx_type: step.txType, tx_info: step.txInfo)]
        )
        let responseHash = Self.normalizedHash(response.transactions.first?.tx_hash ?? "")
        let expectedHash = Self.normalizedHash(step.txHash)
        guard response.transactions.count == 1,
              response.transactions[0].tx_type == step.txType,
              !responseHash.isEmpty,
              !expectedHash.isEmpty,
              responseHash == expectedHash
        else {
            throw PerpsTradingError.protocolFailure("send response does not match the submitted transaction")
        }
    }

    static func normalizedHash(_ hash: String) -> String {
        let value = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
    }

    func executionNSError(_ error: Error) -> NSError {
        let mapped = PerpsTradingErrorMapper.map(error)
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
        case .validation: return .validation
        case .nothingToChange: return .nothingtochange
        case .insufficientBalance: return .insufficientbalance
        case .insufficientLiquidity: return .insufficientliquidity
        case .positionNotFound: return .positionnotfound
        case .immediateLiquidationRisk: return .immediateliquidationrisk
        case .protocolFailure: return .protocolfailure
        case .operationInProgress: return .operationinprogress
        case .stalePreparedTransaction: return .stalepreparedtransaction
        case .submitUnknown: return .submitunknown
        case .unknown: return .unknown
        }
    }

    static func isAmbiguous(_ error: PerpsTradingError) -> Bool {
        switch error {
        case .offline, .timeout, .serverUnavailable, .protocolFailure, .unknown:
            return true
        case .rateLimited, .serverRejected, .authExpired, .credentialsRevoked,
             .activationRequired, .activationCanceled, .regionUnavailable, .validation,
             .nothingToChange, .insufficientBalance, .insufficientLiquidity, .positionNotFound,
             .immediateLiquidationRisk, .operationInProgress, .stalePreparedTransaction,
             .submitUnknown:
            return false
        }
    }
}
