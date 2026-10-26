import Foundation
import TKLogging
import TKPerpsAPI

/// What the backend knows about one recorded deposit.
struct PerpsDepositRecord: Sendable, Equatable {
    enum Status: Sendable, Equatable {
        case pending
        case credited
        /// Not seen within the watch window. Not proof that the money never arrived.
        case unfunded
        case failed
        case refunded
        case expired
        /// Missing status. Never treated as an outcome.
        case unknown
    }

    let depositId: String?
    let status: Status
    let creditedAmount: String?
    let accountIndex: Int64?

    init(_ deposit: Components.Schemas.Deposit) {
        depositId = deposit.deposit_id
        status = switch deposit.status {
        case .pending: .pending
        case .credited: .credited
        case .unfunded: .unfunded
        case .failed: .failed
        case .refunded: .refunded
        case .expired: .expired
        case .none, .unknown: .unknown
        }
        creditedAmount = deposit.credited_amount
        accountIndex = deposit.account_index
    }
}

enum PerpsDepositRegistrationError: Error, Equatable {
    case notADeposit(String)
    case unexpectedStage(String)
    case missingRegistration(String)
    case missingDepositId(String)
    case mismatchedDeposit(String)
}

/// Records a deposit with the backend and follows it without moving money.
struct PerpsDepositRegistrar {
    private let api: PerpsAPI
    private let journal: PerpsPendingJournal

    init(api: PerpsAPI, journal: PerpsPendingJournal) {
        self.api = api
        self.journal = journal
    }

    /// Posts the stored body verbatim. A failure throws, leaving the stage where a later
    /// retry finds it.
    @discardableResult
    func register(operation: PerpsPendingFundingOperation) async throws -> PerpsPendingFundingOperation {
        guard let deposit = operation.deposit else {
            throw PerpsDepositRegistrationError.notADeposit(operation.operationId)
        }
        guard deposit.stage == .registrationPending else {
            throw PerpsDepositRegistrationError.unexpectedStage(operation.operationId)
        }
        guard let registration = deposit.registration else {
            throw PerpsDepositRegistrationError.missingRegistration(operation.operationId)
        }

        let recorded = try await api.openDeposit(
            walletId: operation.walletId,
            request: Self.request(registration)
        )

        try Task.checkCancellation()
        try Self.validate(recorded, operation: operation, expectedTxHash: registration.l1TxHash)
        Self.logStatus(recorded, operation: operation)
        let record = PerpsDepositRecord(recorded)
        return try await update(operation) { deposit in
            // The same transaction may already have a record under another operation id.
            deposit.depositId = record.depositId
            deposit.stage = Self.stage(for: record, whenPending: .registeredPending)
            Self.applyCredit(record, to: &deposit)
        }
    }

    /// Records an unsent main payload. `address_not_bound` keeps the payment for a retry after
    /// binding; other 409 refusals drop it. Cancellation never allows a broadcast. Other failures
    /// defer registration until after broadcast — a deposit is credited recorded or not.
    @discardableResult
    func recordBeforeBroadcast(operation: PerpsPendingFundingOperation) async throws -> PerpsPendingFundingOperation {
        guard let deposit = operation.deposit, deposit.stage == .sourcePending, deposit.depositId == nil,
              let registration = deposit.registration, let transmission = deposit.transmission,
              let mainId = try transmission.operation.parsed().payloads.last?.id,
              !transmission.steps.contains(where: { $0.payloadId == mainId && $0.broadcastAttempted })
        else { return operation }
        let depositId: String?
        do {
            let recorded = try await api.openDeposit(walletId: operation.walletId, request: Self.request(registration))
            try Self.validate(recorded, operation: operation, expectedTxHash: registration.l1TxHash)
            Self.logStatus(recorded, operation: operation)
            depositId = recorded.deposit_id
        } catch let error as PerpsAPIError where error.isAddressNotBound {
            throw error
        } catch let error as PerpsAPIError where error.isAccountCreationPending {
            try await drop(operation, reason: "account_creation_pending")
            throw PerpsDepositServiceError.accountCreationPending
        } catch let PerpsAPIError.badStatus(failure) where failure.httpStatus == 409 {
            try await drop(operation, reason: failure.reason ?? failure.code)
            throw PerpsAPIError.badStatus(failure)
        } catch {
            try Task.checkCancellation()
            Log.perps.w("Perps deposit: record before broadcast deferred op=\(operation.operationId)", error: error)
            return operation
        }
        try Task.checkCancellation()
        return try await update(operation) { deposit in
            deposit.depositId = depositId
        }
    }

    /// Nothing of a payment that never went out is kept; one whose approval did is failed.
    private func drop(_ operation: PerpsPendingFundingOperation, reason: String?) async throws {
        guard operation.deposit?.transmission?.steps.contains(where: \.broadcastAttempted) == true else {
            try await journal.removeFunding(operationId: operation.operationId, expectedRevision: operation.revision)
            return
        }
        _ = try await update(operation) { deposit in
            deposit.stage = .failed
            deposit.failureReason = reason
        }
    }

    @discardableResult
    func refresh(operation: PerpsPendingFundingOperation) async throws -> PerpsPendingFundingOperation {
        guard let deposit = operation.deposit else {
            throw PerpsDepositRegistrationError.notADeposit(operation.operationId)
        }
        guard let depositId = deposit.depositId else {
            throw PerpsDepositRegistrationError.missingDepositId(operation.operationId)
        }
        guard deposit.stage == .registeredPending else {
            throw PerpsDepositRegistrationError.unexpectedStage(operation.operationId)
        }

        let response = try await api.getDeposit(walletId: operation.walletId, depositId: depositId)
        try Task.checkCancellation()
        try Self.validate(
            response,
            operation: operation,
            expectedTxHash: deposit.registration?.l1TxHash,
            expectedDepositId: depositId
        )
        let record = PerpsDepositRecord(response)
        if Self.stage(for: record, whenPending: deposit.stage) != deposit.stage {
            Self.logStatus(response, operation: operation)
        }
        return try await update(operation) { deposit in
            deposit.stage = Self.stage(for: record, whenPending: deposit.stage)
            Self.applyCredit(record, to: &deposit)
        }
    }

    private static func logStatus(_ response: Components.Schemas.Deposit, operation: PerpsPendingFundingOperation) {
        Log.perps.i(
            "Deposit status op=\(operation.operationId) deposit=\(response.deposit_id ?? "nil") status=\(response.status?.rawValue ?? "nil") l1=\(response.l1_tx_hash ?? "nil") credited=\(response.credited_amount ?? "nil")"
        )
    }

    private static func validate(
        _ response: Components.Schemas.Deposit,
        operation: PerpsPendingFundingOperation,
        expectedTxHash: String?,
        expectedDepositId: String? = nil
    ) throws {
        guard let depositId = response.deposit_id,
              !depositId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw PerpsDepositRegistrationError.missingDepositId(operation.operationId)
        }
        if let expectedDepositId, depositId != expectedDepositId {
            throw PerpsDepositRegistrationError.mismatchedDeposit(operation.operationId)
        }
        if let expectedTxHash, let txHash = response.l1_tx_hash,
           txHash.lowercased() != expectedTxHash.lowercased()
        {
            throw PerpsDepositRegistrationError.mismatchedDeposit(operation.operationId)
        }
    }

    private func update(
        _ operation: PerpsPendingFundingOperation,
        _ body: @escaping @Sendable (inout PerpsPendingDeposit) -> Void
    ) async throws -> PerpsPendingFundingOperation {
        try await journal.updateFunding(
            operationId: operation.operationId,
            expectedRevision: operation.revision
        ) { stored in
            guard var deposit = stored.deposit else {
                throw PerpsDepositRegistrationError.notADeposit(stored.operationId)
            }
            body(&deposit)
            stored.details = .deposit(deposit)
        }
    }

    private static func request(
        _ registration: PerpsDepositRegistration
    ) -> Components.Schemas.OpenDepositRequest {
        .init(
            operation_id: registration.operationId,
            asset_id: registration.assetId,
            amount: registration.amount,
            execution_id: registration.executionId,
            l1_tx_hash: registration.l1TxHash
        )
    }

    private static func stage(
        for record: PerpsDepositRecord,
        whenPending: PerpsDepositStage
    ) -> PerpsDepositStage {
        switch record.status {
        case .credited: .credited
        case .unfunded, .expired: .unconfirmed
        case .failed: .failed
        case .refunded: .refunded
        case .pending, .unknown: whenPending
        }
    }

    private static func applyCredit(_ record: PerpsDepositRecord, to deposit: inout PerpsPendingDeposit) {
        // Credited without an amount happens: the only signal was an account appearing.
        // The declared amount must not take its place.
        if let creditedAmount = record.creditedAmount {
            deposit.creditedAmount = creditedAmount
        }
        if let accountIndex = record.accountIndex {
            deposit.accountIndex = accountIndex
        }
    }
}
