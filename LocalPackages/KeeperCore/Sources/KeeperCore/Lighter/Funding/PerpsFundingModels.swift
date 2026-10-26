import Foundation
import PerpsModels

@frozen public enum PerpsFundingState: Sendable, Equatable {
    case unresolved
    case loaded([PerpsPendingFundingOperation])
    case unavailable(lastKnown: [PerpsPendingFundingOperation])

    public var operations: [PerpsPendingFundingOperation] {
        switch self {
        case .unresolved: []
        case let .loaded(operations), let .unavailable(operations): operations
        }
    }
}

@frozen public enum PerpsFundingKind: String, Sendable, Codable {
    case deposit
    case withdraw
}

/// The asset as it was when the operation was prepared. Re-resolving it later could
/// change decimals or id under a payment that is already on its way.
public struct PerpsFundingAsset: Sendable, Equatable, Codable {
    public let assetId: String
    public let symbol: String
    public let decimals: Int

    public init(assetId: String, symbol: String, decimals: Int) {
        self.assetId = assetId
        self.symbol = symbol
        self.decimals = decimals
    }
}

@frozen public enum PerpsDepositRoute: String, Sendable, Codable {
    /// USDC already on Ethereum: gateway call only.
    case directGateway
    /// Provider route from the source asset to a Lighter gateway deposit.
    case crosschainSwap
}

/// Transport evidence is persisted before a transaction can leave the wallet.
@frozen public enum PerpsDepositStage: String, Sendable, Codable {
    case sourcePending
    // Retained to decode journals written before the Generic Payload API flow.
    case draft, preparing, sourceSigned, sourceSending, sourceUnknown, awaitingDelivery
    case readyForGateway, approvalPending, gatewaySigned, gatewaySending, gatewayUnknown
    /// Sent; the registration still has to reach the backend.
    case registrationPending
    case registeredPending
    /// Sent without a registration on record: resuming builds one.
    case needsAuthorization
    case credited
    /// Local view of the backend's `unfunded`: not seen within the watch window,
    /// which is not proof that the money never arrived.
    case unconfirmed
    case failed
    case refunded
}

public extension PerpsDepositStage {
    var isOutcome: Bool {
        switch self {
        case .credited, .failed, .refunded: true
        default: false
        }
    }

    /// No verdict, and nothing left that can produce one: the backend closed its watch and
    /// the client has nothing to send. It is not work in progress, only kept evidence.
    var isStalled: Bool {
        self == .unconfirmed
    }

    /// Money this deposit sent that the Perps balance does not show yet. A record the
    /// backend stopped watching is not waited on.
    var isInFlight: Bool {
        switch self {
        case .sourcePending, .sourceSigned, .sourceSending, .sourceUnknown, .awaitingDelivery, .readyForGateway,
             .gatewaySigned, .gatewaySending, .gatewayUnknown, .registrationPending, .registeredPending, .needsAuthorization: true
        default: false
        }
    }
}

@frozen public enum PerpsWithdrawStage: String, Sendable, Codable {
    case reviewed
    case signed
    case sending
    case unknown
    case accepted
    case awaitingL1
    case settled
    case unconfirmed
    case rejected
}

public extension PerpsWithdrawStage {
    var isBeforeSideEffect: Bool {
        self == .reviewed
    }

    var isOutcome: Bool {
        switch self {
        case .settled, .unconfirmed, .rejected: true
        default: false
        }
    }

    /// Signed and possibly sent, not yet paid out on Ethereum. `unknown` counts: the
    /// withdrawal may be on its way, and saying nothing would invite a second one.
    var isInFlight: Bool {
        switch self {
        case .signed, .sending, .unknown, .accepted, .awaitingL1: true
        case .reviewed, .settled, .unconfirmed, .rejected: false
        }
    }

    var debitsBalance: Bool {
        switch self {
        case .accepted, .awaitingL1, .settled, .unconfirmed: true
        case .reviewed, .signed, .sending, .unknown, .rejected: false
        }
    }
}

public struct PerpsPendingL1Step: Sendable, Equatable, Codable {
    public let stepId: String
    public let attemptId: String
    public let chainId: Int64
    public let sender: String
    public let nonce: Int64
    public let signedTransaction: String
    public let txHash: String
    public var state: PerpsPendingStepState
    /// Unix seconds after which a TON wallet refuses the signed bytes; absent on EVM.
    public let validUntil: Int64?

    public init(
        stepId: String,
        attemptId: String,
        chainId: Int64,
        sender: String,
        nonce: Int64,
        signedTransaction: String,
        txHash: String,
        state: PerpsPendingStepState,
        validUntil: Int64? = nil
    ) {
        self.stepId = stepId
        self.attemptId = attemptId
        self.chainId = chainId
        self.sender = sender
        self.nonce = nonce
        self.signedTransaction = signedTransaction
        self.txHash = txHash
        self.state = state
        self.validUntil = validUntil
    }
}

struct PerpsDepositTransmission: Sendable, Equatable, Codable {
    let operation: PerpsDepositOperation
    let sender: String
    let expiresAt: Date
    var steps: [ChainKitSignedTransaction]
}

/// The exact registration body. A retry repeats it verbatim: the backend keys the record by
/// `operationId`, and a changed amount under the same one is a conflict.
public struct PerpsDepositRegistration: Sendable, Equatable, Codable {
    public let operationId: String
    public let assetId: String
    public let amount: String
    public let l1TxHash: String?
    public let executionId: String?

    public init(
        operationId: String,
        assetId: String,
        amount: String,
        l1TxHash: String?,
        executionId: String?
    ) {
        self.operationId = operationId
        self.assetId = assetId
        self.amount = amount
        self.l1TxHash = l1TxHash
        self.executionId = executionId
    }
}

public struct PerpsPendingDeposit: Sendable, Equatable, Codable {
    public var stage: PerpsDepositStage
    public let route: PerpsDepositRoute
    /// The wallet's own Ethereum address the deposit is credited to.
    public let beneficiary: String
    public let sourceAsset: PerpsFundingAsset
    public let sourceAmountUnits: String
    public let targetAsset: PerpsFundingAsset
    public var minimumTargetAmountUnits: String?
    public var executionId: String?
    /// The last transaction the deposit broadcast: the one that moves the money.
    public var sourceTxHash: String?
    public var sourceStep: PerpsPendingL1Step?
    public var approvalStep: PerpsPendingL1Step?
    public var gatewayStep: PerpsPendingL1Step?
    public var deliveryTxHash: String?
    public var gatewayAmountUnits: String?
    public var quoteExpiresAtMillis: Int64?
    var transmission: PerpsDepositTransmission?
    public var quoteId: String?
    public var registration: PerpsDepositRegistration?
    public var depositId: String?
    public var creditedAmount: String?
    public var accountIndex: Int64?
    public var failureReason: String?

    public init(
        stage: PerpsDepositStage,
        route: PerpsDepositRoute,
        beneficiary: String,
        sourceAsset: PerpsFundingAsset,
        sourceAmountUnits: String,
        targetAsset: PerpsFundingAsset,
        minimumTargetAmountUnits: String? = nil,
        executionId: String? = nil,
        sourceTxHash: String? = nil,
        quoteId: String? = nil,
        registration: PerpsDepositRegistration? = nil,
        depositId: String? = nil,
        creditedAmount: String? = nil,
        accountIndex: Int64? = nil,
        failureReason: String? = nil
    ) {
        self.stage = stage
        self.route = route
        self.beneficiary = beneficiary
        self.sourceAsset = sourceAsset
        self.sourceAmountUnits = sourceAmountUnits
        self.targetAsset = targetAsset
        self.minimumTargetAmountUnits = minimumTargetAmountUnits
        self.executionId = executionId
        self.sourceTxHash = sourceTxHash
        self.quoteId = quoteId
        self.registration = registration
        self.depositId = depositId
        self.creditedAmount = creditedAmount
        self.accountIndex = accountIndex
        self.failureReason = failureReason
    }
}

extension PerpsPendingDeposit {
    var requiresResume: Bool {
        if stage == .approvalPending, sourceStep == nil, gatewayStep == nil { return false }
        return switch stage {
        case .sourcePending, .needsAuthorization, .sourceSigned, .sourceSending, .sourceUnknown,
             .awaitingDelivery, .readyForGateway, .approvalPending, .gatewaySigned, .gatewaySending, .gatewayUnknown: true
        default: false
        }
    }

    var blocksNewPayment: Bool {
        requiresResume && stage != .needsAuthorization
    }
}

public struct PerpsPendingWithdraw: Sendable, Equatable, Codable {
    public var stage: PerpsWithdrawStage
    public let accountIndex: Int64
    public let apiKeyIndex: Int32
    public let chainId: Int32
    public let assetIndex: Int32
    public let routeType: Int32
    public let amountUnits: String
    public let destinationAssetId: String?
    public let recipient: String?
    public let executionId: String?
    public let quoteId: String?
    /// A relay transfer is not replayed past this: the relay would be paid on expired terms.
    public let quoteExpiresAtMillis: Int64?
    public let outputUnits: String?
    /// Every signed attempt of this intent. An unresolved one is never overwritten:
    /// it is the only record of a submission the venue may have accepted.
    public var steps: [PerpsPendingSignedStep]
    public var withdrawalId: String?
    public var l1TxHash: String?
    public var failureReason: String?

    public init(
        stage: PerpsWithdrawStage,
        accountIndex: Int64,
        apiKeyIndex: Int32,
        chainId: Int32,
        assetIndex: Int32,
        routeType: Int32,
        amountUnits: String,
        destinationAssetId: String? = nil,
        recipient: String? = nil,
        executionId: String? = nil,
        quoteId: String? = nil,
        quoteExpiresAtMillis: Int64? = nil,
        outputUnits: String? = nil,
        steps: [PerpsPendingSignedStep] = [],
        withdrawalId: String? = nil,
        l1TxHash: String? = nil,
        failureReason: String? = nil
    ) {
        self.stage = stage
        self.accountIndex = accountIndex
        self.apiKeyIndex = apiKeyIndex
        self.chainId = chainId
        self.assetIndex = assetIndex
        self.routeType = routeType
        self.amountUnits = amountUnits
        self.destinationAssetId = destinationAssetId
        self.recipient = recipient
        self.executionId = executionId
        self.quoteId = quoteId
        self.quoteExpiresAtMillis = quoteExpiresAtMillis
        self.outputUnits = outputUnits
        self.steps = steps
        self.withdrawalId = withdrawalId
        self.l1TxHash = l1TxHash
        self.failureReason = failureReason
    }

    public var unresolvedStep: PerpsPendingSignedStep? {
        steps.last { $0.state == .sending || $0.state == .unknown }
    }

    /// An accepted submission has spent its nonce; the next payment checks the live balance.
    var blocksNewWithdrawal: Bool {
        switch stage {
        case .signed, .sending, .unknown: true
        case .reviewed, .accepted, .awaitingL1, .settled, .unconfirmed, .rejected: false
        }
    }

    /// Past its nonce the last attempt can no longer land, but that is no proof it did: trades
    /// and integrator approvals share the lane. Only the relay or the venue's history can say.
    func noncePassed(accountIndex: Int64, nextNonce: Int64) -> Bool {
        self.accountIndex == accountIndex && steps.last.map { nextNonce > $0.nonce } == true
    }
}

@frozen public enum PerpsPendingFundingDetails: Sendable, Equatable, Codable {
    case deposit(PerpsPendingDeposit)
    case withdraw(PerpsPendingWithdraw)
}

/// One funding intent, durable across launches. The identity fields never change:
/// a new amount or a new payment is a new operation, not an edit of this one.
public struct PerpsPendingFundingOperation: Sendable, Equatable, Codable {
    public let operationId: String
    public let walletId: String
    /// Local wallet identity, so a record cannot be applied to another wallet.
    public let walletIdentity: String
    public let environment: String
    public let createdAtMillis: Int64
    public internal(set) var updatedAtMillis: Int64
    /// Bumped by the journal on every stored change; a caller passes the revision it
    /// read so a late callback cannot overwrite a newer stage.
    public internal(set) var revision: Int
    public var details: PerpsPendingFundingDetails

    public init(
        operationId: String,
        walletId: String,
        walletIdentity: String,
        environment: String,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        updatedAtMillis: Int64? = nil,
        revision: Int = 0,
        details: PerpsPendingFundingDetails
    ) {
        self.operationId = operationId
        self.walletId = walletId
        self.walletIdentity = walletIdentity
        self.environment = environment
        self.createdAtMillis = createdAtMillis
        self.updatedAtMillis = updatedAtMillis ?? createdAtMillis
        self.revision = revision
        self.details = details
    }

    public var kind: PerpsFundingKind {
        switch details {
        case .deposit: .deposit
        case .withdraw: .withdraw
        }
    }

    public var deposit: PerpsPendingDeposit? {
        guard case let .deposit(deposit) = details else { return nil }
        return deposit
    }

    public var withdraw: PerpsPendingWithdraw? {
        guard case let .withdraw(withdraw) = details else { return nil }
        return withdraw
    }

    /// Every hash that can name this operation in the activity feed. An allowance is its own
    /// transaction, not the deposit, so it is left out.
    var transactionHashes: Set<String> {
        let hashes: [String?] = switch details {
        case let .deposit(deposit):
            [deposit.sourceTxHash, deposit.gatewayStep?.txHash, deposit.sourceStep?.txHash, deposit.registration?.l1TxHash]
        case let .withdraw(withdraw):
            withdraw.steps.map(\.txHash) + [withdraw.l1TxHash]
        }
        return Set(hashes.compactMap { $0 }.filter { !$0.isEmpty })
    }

    /// Whether this record is one of the given scope's. All three have to agree: the same
    /// venue under another wallet, or another install of the same wallet, is not this one.
    func belongs(walletId: String?, walletIdentity: String, environment: String) -> Bool {
        self.walletId == walletId && self.walletIdentity == walletIdentity && self.environment == environment
    }

    public var isBeforeSideEffect: Bool {
        switch details {
        case let .deposit(deposit): deposit.stage == .draft || deposit.stage == .preparing
        case let .withdraw(withdraw): withdraw.stage.isBeforeSideEffect
        }
    }

    public var isOutcome: Bool {
        switch details {
        case let .deposit(deposit): deposit.stage.isOutcome
        case let .withdraw(withdraw): withdraw.stage.isOutcome
        }
    }

    /// Needs reconciliation and must not be aged out. Whether it blocks another
    /// submission depends on its signed steps and execution lane, not its kind alone.
    public var isUnresolved: Bool {
        !isBeforeSideEffect && !isOutcome
    }

    /// Unresolved, but with no side left to reconcile against. A withdraw is never here:
    /// its unknown attempt is still owed an answer.
    public var isStalled: Bool {
        switch details {
        case let .deposit(deposit): deposit.stage.isStalled
        case .withdraw: false
        }
    }
}
