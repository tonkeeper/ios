import ChainKit
import Foundation

public enum PerpsTradeSide: String, Sendable, Equatable, Codable {
    case long
    case short
}

public enum PerpsLiquidationUnavailableReason: String, Sendable, Equatable, Codable {
    case flatPosition
    case missingMark
    case missingCollateral
    case missingMaintenanceFraction
    case zeroDenominator
    case negativePrice
    case unknown
}

public struct PerpsAutoCloseTrigger: Sendable, Equatable, Codable {
    public let triggerPrice: Double

    public init(triggerPrice: Double) {
        self.triggerPrice = triggerPrice
    }
}

public struct PerpsAutoClose: Sendable, Equatable, Codable {
    public let takeProfit: PerpsAutoCloseTrigger?
    public let stopLoss: PerpsAutoCloseTrigger?

    public init(takeProfit: PerpsAutoCloseTrigger?, stopLoss: PerpsAutoCloseTrigger?) {
        self.takeProfit = takeProfit
        self.stopLoss = stopLoss
    }

    public var isEmpty: Bool {
        takeProfit == nil && stopLoss == nil
    }
}

public struct PerpsOpenMarketIntent: Sendable, Equatable {
    public let marketId: Int64
    public let side: PerpsTradeSide
    public let marginUsd: String
    public let leverage: Double
    public let maxSlippage: Double
    public let autoClose: PerpsAutoClose?
    public let limitPrice: Double?

    public init(
        marketId: Int64,
        side: PerpsTradeSide,
        marginUsd: String,
        leverage: Double,
        maxSlippage: Double,
        autoClose: PerpsAutoClose?,
        limitPrice: Double? = nil
    ) {
        self.marketId = marketId
        self.side = side
        self.marginUsd = marginUsd
        self.leverage = leverage
        self.maxSlippage = maxSlippage
        self.autoClose = autoClose
        self.limitPrice = limitPrice
    }
}

public struct PerpsLeverageBounds: Sendable, Equatable {
    public let min: Double
    public let max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

public struct PerpsOpenMarketContext: Sendable, Equatable {
    public let marketId: Int64
    public let side: PerpsTradeSide
    public let symbol: String
    public let displayPrice: Double
    public let priceDecimals: Int
    public let sizeDecimals: Int
    public let leverageBounds: PerpsLeverageBounds
    public let defaultLeverage: Double
    public let maxSlippage: Double
    public let minBaseSize: Double

    public init(
        marketId: Int64,
        side: PerpsTradeSide,
        symbol: String,
        displayPrice: Double,
        priceDecimals: Int,
        sizeDecimals: Int,
        leverageBounds: PerpsLeverageBounds,
        defaultLeverage: Double,
        maxSlippage: Double,
        minBaseSize: Double
    ) {
        self.marketId = marketId
        self.side = side
        self.symbol = symbol
        self.displayPrice = displayPrice
        self.priceDecimals = priceDecimals
        self.sizeDecimals = sizeDecimals
        self.leverageBounds = leverageBounds
        self.defaultLeverage = defaultLeverage
        self.maxSlippage = maxSlippage
        self.minBaseSize = minBaseSize
    }
}

public struct PerpsOpenOrderReview: Sendable, Equatable {
    public let symbol: String
    public let marginUsd: Double
    public let entryPrice: Double?
    public let liquidationPrice: Double?
    public let notionalUsd: Double
    public let baseSize: Double
    public let estimatedFeeUsd: Double?
    public let liquidationUnavailableReason: PerpsLiquidationUnavailableReason?

    public init(
        symbol: String,
        marginUsd: Double,
        entryPrice: Double?,
        liquidationPrice: Double?,
        notionalUsd: Double,
        baseSize: Double,
        estimatedFeeUsd: Double?,
        liquidationUnavailableReason: PerpsLiquidationUnavailableReason?
    ) {
        self.symbol = symbol
        self.marginUsd = marginUsd
        self.entryPrice = entryPrice
        self.liquidationPrice = liquidationPrice
        self.notionalUsd = notionalUsd
        self.baseSize = baseSize
        self.estimatedFeeUsd = estimatedFeeUsd
        self.liquidationUnavailableReason = liquidationUnavailableReason
    }
}

/// What every prepared action carries regardless of the operation: the identity a
/// submission is journalled and reconciled under.
protocol PerpsPreparedAction {
    var operationId: String { get }
    var walletId: String { get }
    var marketId: Int64 { get }
}

public struct PerpsPreparedTradingAction: Sendable {
    public let operationId: String
    public let walletId: String
    public let marketId: Int64
    public let intent: PerpsOpenMarketIntent
    public let review: PerpsOpenOrderReview
}

public struct PerpsCloseIntent: Sendable, Equatable {
    public let marketId: Int64

    public init(marketId: Int64) {
        self.marketId = marketId
    }
}

public struct PerpsCloseReview: Sendable, Equatable {
    public let symbol: String
    /// Side of the position being closed, not the closing order's side.
    public let side: PerpsTradeSide
    public let leverage: Double?
    public let marginUsd: Double
    public let notionalUsd: Double
    public let baseSize: Double
    public let estimatedFeeUsd: Double?
    public let estimatedPnlUsd: Double?
    public let estimatedReceiveUsd: Double?

    public var estimatedPnlPercent: Double? {
        guard marginUsd > 0, let estimatedPnlUsd else { return nil }
        return estimatedPnlUsd / marginUsd * 100
    }

    public init(
        symbol: String,
        side: PerpsTradeSide,
        leverage: Double?,
        marginUsd: Double,
        notionalUsd: Double,
        baseSize: Double,
        estimatedFeeUsd: Double?,
        estimatedPnlUsd: Double?,
        estimatedReceiveUsd: Double?
    ) {
        self.symbol = symbol
        self.side = side
        self.leverage = leverage
        self.marginUsd = marginUsd
        self.notionalUsd = notionalUsd
        self.baseSize = baseSize
        self.estimatedFeeUsd = estimatedFeeUsd
        self.estimatedPnlUsd = estimatedPnlUsd
        self.estimatedReceiveUsd = estimatedReceiveUsd
    }
}

public struct PerpsPreparedCloseAction: Sendable {
    public let operationId: String
    public let walletId: String
    public let marketId: Int64
    public let positionBaseAmount: Int64
    public let review: PerpsCloseReview
}

public enum PerpsSizeChangeDirection: String, Sendable, Equatable, Codable {
    case add
    case reduce
}

public enum PerpsAutoCloseUpdate: Sendable, Equatable {
    case unchanged
    case clear
    case replace(PerpsAutoClose)

    public init(desired: PerpsAutoClose?, resting: PerpsAutoClose?) {
        let desired = desired.flatMap { $0.isEmpty ? nil : $0 }
        let resting = resting.flatMap { $0.isEmpty ? nil : $0 }
        if desired == resting {
            self = .unchanged
        } else if let desired {
            self = .replace(desired)
        } else {
            self = .clear
        }
    }

    public func applying(to resting: PerpsAutoClose?) -> PerpsAutoClose? {
        switch self {
        case .unchanged:
            resting.flatMap { $0.isEmpty ? nil : $0 }
        case .clear:
            nil
        case let .replace(value):
            value.isEmpty ? nil : value
        }
    }

    fileprivate var normalized: Self {
        if case let .replace(value) = self, value.isEmpty {
            return .clear
        }
        return self
    }
}

public struct PerpsSizeChangeIntent: Sendable, Equatable {
    public let marketId: Int64
    public let direction: PerpsSizeChangeDirection
    public let marginDeltaUsd: String
    public let autoCloseUpdate: PerpsAutoCloseUpdate

    public init(
        marketId: Int64,
        direction: PerpsSizeChangeDirection,
        marginDeltaUsd: String,
        autoCloseUpdate: PerpsAutoCloseUpdate = .unchanged
    ) {
        self.marketId = marketId
        self.direction = direction
        self.marginDeltaUsd = marginDeltaUsd
        self.autoCloseUpdate = autoCloseUpdate.normalized
    }
}

public struct PerpsValueChange: Sendable, Equatable {
    public let old: Double
    public let new: Double

    public var isChanged: Bool {
        old != new
    }

    public init(old: Double, new: Double) {
        self.old = old
        self.new = new
    }
}

public struct PerpsSizeChangeReview: Sendable, Equatable {
    public let symbol: String
    public let direction: PerpsSizeChangeDirection
    /// Side of the position being resized, not the resizing order's side.
    public let side: PerpsTradeSide
    public let leverage: Double?
    public let marginDeltaUsd: Double
    public let entryPrice: PerpsValueChange
    public let notionalUsd: PerpsValueChange
    public let baseSize: PerpsValueChange
    public let liquidationPrice: Double?
    public let liquidationUnavailableReason: PerpsLiquidationUnavailableReason?
    public let estimatedFeeUsd: Double?

    public init(
        symbol: String,
        direction: PerpsSizeChangeDirection,
        side: PerpsTradeSide,
        leverage: Double?,
        marginDeltaUsd: Double,
        entryPrice: PerpsValueChange,
        notionalUsd: PerpsValueChange,
        baseSize: PerpsValueChange,
        liquidationPrice: Double?,
        liquidationUnavailableReason: PerpsLiquidationUnavailableReason?,
        estimatedFeeUsd: Double?
    ) {
        self.symbol = symbol
        self.direction = direction
        self.side = side
        self.leverage = leverage
        self.marginDeltaUsd = marginDeltaUsd
        self.entryPrice = entryPrice
        self.notionalUsd = notionalUsd
        self.baseSize = baseSize
        self.liquidationPrice = liquidationPrice
        self.liquidationUnavailableReason = liquidationUnavailableReason
        self.estimatedFeeUsd = estimatedFeeUsd
    }
}

public struct PerpsPreparedSizeChangeAction: Sendable {
    public let operationId: String
    public let walletId: String
    public let marketId: Int64
    public let intent: PerpsSizeChangeIntent
    public let review: PerpsSizeChangeReview
    public let normalizedAutoClose: PerpsAutoClose?
}

public enum PerpsMarginChangeDirection: String, Sendable, Equatable, Codable {
    case add
    case reduce
}

public struct PerpsMarginChangeIntent: Sendable, Equatable {
    public let marketId: Int64
    public let direction: PerpsMarginChangeDirection
    public let amountUsd: String

    public init(marketId: Int64, direction: PerpsMarginChangeDirection, amountUsd: String) {
        self.marketId = marketId
        self.direction = direction
        self.amountUsd = amountUsd
    }
}

public struct PerpsMarginChangeReview: Sendable, Equatable {
    public let symbol: String
    public let direction: PerpsMarginChangeDirection
    /// Side of the position whose margin changes — no order is placed.
    public let side: PerpsTradeSide
    public let leverage: Double?
    public let amountUsd: Double
    public let allocatedMargin: PerpsValueChange
    public let liquidationPrice: PerpsValueChange?
    public let liquidationUnavailableReason: PerpsLiquidationUnavailableReason?
    public let isImmediateRisk: Bool

    public init(
        symbol: String,
        direction: PerpsMarginChangeDirection,
        side: PerpsTradeSide,
        leverage: Double?,
        amountUsd: Double,
        allocatedMargin: PerpsValueChange,
        liquidationPrice: PerpsValueChange?,
        liquidationUnavailableReason: PerpsLiquidationUnavailableReason?,
        isImmediateRisk: Bool
    ) {
        self.symbol = symbol
        self.direction = direction
        self.side = side
        self.leverage = leverage
        self.amountUsd = amountUsd
        self.allocatedMargin = allocatedMargin
        self.liquidationPrice = liquidationPrice
        self.liquidationUnavailableReason = liquidationUnavailableReason
        self.isImmediateRisk = isImmediateRisk
    }
}

public struct PerpsPreparedMarginChangeAction: Sendable {
    public let operationId: String
    public let walletId: String
    public let marketId: Int64
    public let intent: PerpsMarginChangeIntent
    public let review: PerpsMarginChangeReview
}

public struct PerpsAutoCloseChangeIntent: Sendable, Equatable {
    public let marketId: Int64
    /// The full desired TP/SL state for the position; an empty target clears
    /// the resting legs.
    public let target: PerpsAutoClose

    public init(marketId: Int64, target: PerpsAutoClose) {
        self.marketId = marketId
        self.target = target
    }
}

public struct PerpsAutoCloseChangeReview: Sendable, Equatable {
    /// Side of the position the legs protect, not the trigger orders' side.
    public let side: PerpsTradeSide
    /// nil = the change clears the legs. Trigger prices are the SDK review's
    /// post-rounding values, so the reconcile predicate compares against what
    /// the venue actually stores, not the raw user input.
    public let new: PerpsAutoClose?

    public init(side: PerpsTradeSide, new: PerpsAutoClose?) {
        self.side = side
        self.new = new
    }
}

public struct PerpsPreparedAutoCloseChangeAction: Sendable {
    public let operationId: String
    public let walletId: String
    public let marketId: Int64
    public let intent: PerpsAutoCloseChangeIntent
    public let review: PerpsAutoCloseChangeReview
}

public enum PerpsLimitOrderChangeKind: String, Sendable, Equatable, Codable {
    case modify
    case cancel
}

public enum PerpsLimitOrderChangeIntent: Sendable, Equatable {
    case modify(marketId: Int64, orderIndex: Int64, limitPrice: Double)
    case cancel(marketId: Int64, orderIndex: Int64)

    public var marketId: Int64 {
        switch self {
        case let .modify(marketId, _, _), let .cancel(marketId, _): marketId
        }
    }

    public var orderIndex: Int64 {
        switch self {
        case let .modify(_, orderIndex, _), let .cancel(_, orderIndex): orderIndex
        }
    }

    public var kind: PerpsLimitOrderChangeKind {
        switch self {
        case .modify: .modify
        case .cancel: .cancel
        }
    }

    public var limitPrice: Double? {
        switch self {
        case let .modify(_, _, limitPrice): limitPrice
        case .cancel: nil
        }
    }
}

public struct PerpsLimitOrderChangeReview: Sendable, Equatable {
    public let order: PerpsLimitOrderSummary
    public let kind: PerpsLimitOrderChangeKind
    public let limitPrice: Double?

    public init(
        order: PerpsLimitOrderSummary,
        kind: PerpsLimitOrderChangeKind,
        limitPrice: Double?
    ) {
        self.order = order
        self.kind = kind
        self.limitPrice = limitPrice
    }
}

public struct PerpsPreparedLimitOrderChangeAction: Sendable {
    public let operationId: String
    public let walletId: String
    public let marketId: Int64
    public let intent: PerpsLimitOrderChangeIntent
    public let review: PerpsLimitOrderChangeReview
}

public struct PerpsPendingLimitOrderChange: Sendable, Equatable, Codable {
    public let orderIndex: Int64
    public let kind: PerpsLimitOrderChangeKind
    public let limitPrice: Double?

    public init(orderIndex: Int64, kind: PerpsLimitOrderChangeKind, limitPrice: Double?) {
        self.orderIndex = orderIndex
        self.kind = kind
        self.limitPrice = limitPrice
    }
}

public struct PerpsPendingAutoCloseChange: Sendable, Equatable, Codable {
    /// nil = clearing; trigger prices are post-rounding (from the SDK review).
    public let target: PerpsAutoClose?
    public let restingOrderIndexes: [Int64]

    public init(target: PerpsAutoClose?, restingOrderIndexes: [Int64]) {
        self.target = target
        self.restingOrderIndexes = restingOrderIndexes
    }
}

/// One market read, able to review a trade over itself. The planner is pure, so a
/// review is synchronous and costs no network: a screen loads a reviewer once and
/// recomputes as the user drags. `nil` means this read no longer answers for that
/// intent — it went stale, or stopped covering the size — and the caller reloads.
public protocol PerpetualReviewer: AnyObject, Sendable {
    /// True once this read is old enough that the client should ask the backend for
    /// a new one. Separate from the planner's own limit: the planner says when a
    /// read is unusable, this says when it is merely worth replacing.
    var isStale: Bool { get }

    func reviewOpen(_ intent: PerpsOpenMarketIntent) -> PerpsOpenOrderReview?
    func reviewMarginChange(_ intent: PerpsMarginChangeIntent) -> PerpsMarginChangeReview?
}

struct PerpsReviewInputs {
    let context: PerpsMarketContext
    let marketSnapshot: PerpetualMarketSnapshot?
    let symbol: String
}

public enum PerpsPendingOrderRole: String, Sendable, Codable {
    case parent
    case takeProfit
    case stopLoss
    case close
    case add
}

public struct PerpsPendingOrderRef: Sendable, Equatable, Codable {
    public let role: PerpsPendingOrderRole
    public let clientOrderIndex: Int64

    public init(role: PerpsPendingOrderRole, clientOrderIndex: Int64) {
        self.role = role
        self.clientOrderIndex = clientOrderIndex
    }
}

public enum PerpsPendingStepState: String, Sendable, Equatable, Codable {
    case signed
    case sending
    case unknown
    case accepted
}

/// Durable transport data for one execution step. The signed payload is kept
/// separately from order refs so a crash before POST can resume the exact tx.
public struct PerpsPendingSignedStep: Sendable, Equatable, Codable {
    public let stepId: String
    public let attemptId: String
    public let nonce: Int64
    public let transactionExpiryUnixMs: Int64
    public let txType: Int32
    public let txInfo: String
    public let txHash: String
    public let state: PerpsPendingStepState

    public init(
        stepId: String,
        attemptId: String,
        nonce: Int64,
        transactionExpiryUnixMs: Int64,
        txType: Int32,
        txInfo: String,
        txHash: String,
        state: PerpsPendingStepState
    ) {
        self.stepId = stepId
        self.attemptId = attemptId
        self.nonce = nonce
        self.transactionExpiryUnixMs = transactionExpiryUnixMs
        self.txType = txType
        self.txInfo = txInfo
        self.txHash = txHash
        self.state = state
    }

    func withState(_ state: PerpsPendingStepState) -> Self {
        Self(
            stepId: stepId,
            attemptId: attemptId,
            nonce: nonce,
            transactionExpiryUnixMs: transactionExpiryUnixMs,
            txType: txType,
            txInfo: txInfo,
            txHash: txHash,
            state: state
        )
    }
}

public enum PerpsPendingPayload: Sendable, Equatable, Codable {
    case open(limitPrice: Double?)
    case close
    case sizeChange(PerpsPendingSizeChange, autoClose: PerpsPendingAutoCloseChange?)
    case marginChange(PerpsPendingMarginChange)
    case autoCloseChange(PerpsPendingAutoCloseChange)
    case limitOrderChange(PerpsPendingLimitOrderChange)

    /// Whether the operation can leave an order resting on the venue after it is sent.
    /// A margin move settles or fails at once and leaves nothing behind; everything
    /// else can place, replace or cancel an order that outlives the submission.
    var leavesRestingOrder: Bool {
        switch self {
        case .marginChange:
            return false
        case .open, .close, .sizeChange, .autoCloseChange, .limitOrderChange:
            return true
        }
    }
}

public struct PerpsPendingTradingAction: Sendable, Equatable, Codable {
    public let operationId: String
    public let createdAtMillis: Int64
    public let walletId: String
    public let marketId: Int64
    public let side: PerpsTradeSide
    public let payload: PerpsPendingPayload
    /// When the last order this operation can place stops being resting. Nil for an
    /// operation that leaves nothing behind.
    public let expiresAtMillis: Int64?
    /// Expected base amount for a market open, or the position amount captured before a close.
    /// Nil when the operation has no expected base amount.
    public let expectedBaseSize: Double?
    public let positionBaseSizeBefore: Double?
    public var orderRefs: [PerpsPendingOrderRef]?
    public var signedSteps: [PerpsPendingSignedStep]?

    public init(
        operationId: String,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        walletId: String,
        marketId: Int64,
        side: PerpsTradeSide,
        payload: PerpsPendingPayload,
        expiresAtMillis: Int64? = nil,
        expectedBaseSize: Double? = nil,
        positionBaseSizeBefore: Double? = nil,
        orderRefs: [PerpsPendingOrderRef]? = nil,
        signedSteps: [PerpsPendingSignedStep]? = nil
    ) {
        self.operationId = operationId
        self.createdAtMillis = createdAtMillis
        self.walletId = walletId
        self.marketId = marketId
        self.side = side
        self.payload = payload
        self.expiresAtMillis = expiresAtMillis
        self.expectedBaseSize = expectedBaseSize
        self.positionBaseSizeBefore = positionBaseSizeBefore
        self.orderRefs = orderRefs
        self.signedSteps = signedSteps
    }

    var positionOrderRef: PerpsPendingOrderRef? {
        orderRefs?.first { $0.role == .parent || $0.role == .close || $0.role == .add }
    }

    var triggerOrderRefs: [PerpsPendingOrderRef] {
        orderRefs?.filter { $0.role == .takeProfit || $0.role == .stopLoss } ?? []
    }

    var hasOnlyAcceptedSignedSteps: Bool {
        guard let signedSteps, !signedSteps.isEmpty else { return false }
        return signedSteps.allSatisfy { $0.state == .accepted }
    }
}

public struct PerpsPendingMarginChange: Sendable, Equatable, Codable {
    public let direction: PerpsMarginChangeDirection
    public let allocatedMarginBefore: Double
    public let amountUsd: Double

    public init(direction: PerpsMarginChangeDirection, allocatedMarginBefore: Double, amountUsd: Double) {
        self.direction = direction
        self.allocatedMarginBefore = allocatedMarginBefore
        self.amountUsd = amountUsd
    }
}

public struct PerpsPendingSizeChange: Sendable, Equatable, Codable {
    public let direction: PerpsSizeChangeDirection
    public let baseSizeBefore: Double
    public let expectedBaseDelta: Double?

    public init(
        direction: PerpsSizeChangeDirection,
        baseSizeBefore: Double,
        expectedBaseDelta: Double? = nil
    ) {
        self.direction = direction
        self.baseSizeBefore = baseSizeBefore
        self.expectedBaseDelta = expectedBaseDelta
    }
}

enum PerpsChangeSettlement {
    static func sizeMoved(current: Double, before: Double, direction: PerpsSizeChangeDirection) -> Bool {
        switch direction {
        case .add: current > before
        case .reduce: current < before
        }
    }

    static func sizeMoved(
        current: Double,
        before: Double,
        direction: PerpsSizeChangeDirection,
        expectedDelta: Double?
    ) -> Bool {
        let observed = direction == .add ? current - before : before - current
        guard observed > 0 else { return false }
        guard let expectedDelta else { return true }
        let tolerance = max(0.000000001, abs(expectedDelta) * 1e-9)
        return observed + tolerance >= expectedDelta
    }

    static func closeMoved(current: Double, before: Double) -> Bool {
        current < before
    }

    static func marginMoved(current: Double, before: Double, amountUsd: Double, direction: PerpsMarginChangeDirection) -> Bool {
        let observedDelta = current - before
        // UpdateMargin is scaled to 1e-6 USDC. Allow only wire-rounding noise;
        // a half-amount threshold can turn unrelated funding/margin drift into success.
        let tolerance = max(0.000001, abs(amountUsd) * 1e-9)
        let requiredDelta = max(0, amountUsd - tolerance)
        switch direction {
        case .add: return observedDelta >= requiredDelta
        case .reduce: return -observedDelta >= requiredDelta
        }
    }
}

public enum PerpsSubmitResult: Sendable {
    case submitted(PerpsPendingTradingAction)
    case failed(PerpsTradingError)
    case submitUnknown(PerpsPendingTradingAction)
}

/// What became of one submitted operation. Refreshing the portfolio afterwards is
/// a separate concern: a read that fails there cannot unsettle a settled trade.
public enum PerpsReconcileResult: Sendable, Equatable {
    case confirmed
    case failed(PerpsTradingError)
    case pending
}

public enum PerpsTradingError: Error, Sendable, Equatable {
    case offline
    case timeout
    case rateLimited
    case serverUnavailable
    case serverRejected(String)
    case authExpired
    case credentialsRevoked
    case activationRequired
    case activationCanceled
    case regionUnavailable
    case validation(String)
    /// The venue is already in the requested state — nothing to submit.
    case nothingToChange
    case insufficientBalance
    case insufficientLiquidity
    case positionNotFound
    /// The change would leave the position at or under its maintenance margin.
    case immediateLiquidationRisk
    case protocolFailure(String)
    case operationInProgress
    case stalePreparedTransaction
    case submitUnknown
    case unknown(String)
}

extension PerpsPreparedTradingAction: PerpsPreparedAction {}
extension PerpsPreparedCloseAction: PerpsPreparedAction {}
extension PerpsPreparedSizeChangeAction: PerpsPreparedAction {}
extension PerpsPreparedMarginChangeAction: PerpsPreparedAction {}
extension PerpsPreparedAutoCloseChangeAction: PerpsPreparedAction {}
extension PerpsPreparedLimitOrderChangeAction: PerpsPreparedAction {}
