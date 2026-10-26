@testable import App
import Foundation
@testable import KeeperCore
@testable import Perps
import PerpsModels

/// Test double for the KeeperCore trading seam so App view models can be tested
/// without ChainKit/session plumbing.
final class FakePerpsTradingService: PerpsTradingService, @unchecked Sendable {
    var context: PerpsOpenMarketContext?
    /// When true, `openMarketContext` returns nil to exercise the terminal load-error path.
    var failsMarketLoad = false
    var previewResult: Result<PerpsOpenOrderReview, PerpsTradingError> = .success(FakePerpsTradingService.makeReview())
    var previewHandler: ((PerpsOpenMarketIntent) -> Result<PerpsOpenOrderReview, PerpsTradingError>)?
    var previewSuspension: (() async -> Void)?
    var prepareResult: Result<PerpsPreparedTradingAction, PerpsTradingError> = .failure(.unknown("not set"))
    var previewCloseResult: Result<PerpsCloseReview, PerpsTradingError> = .failure(.unknown("not set"))
    var prepareCloseResult: Result<PerpsPreparedCloseAction, PerpsTradingError> = .failure(.unknown("not set"))
    var previewSizeChangeResult: Result<PerpsSizeChangeReview, PerpsTradingError> = .failure(.unknown("not set"))
    var prepareSizeChangeResult: Result<PerpsPreparedSizeChangeAction, PerpsTradingError> = .failure(.unknown("not set"))
    var previewMarginChangeResult: Result<PerpsMarginChangeReview, PerpsTradingError> = .failure(.unknown("not set"))
    var prepareMarginChangeResult: Result<PerpsPreparedMarginChangeAction, PerpsTradingError> = .failure(.unknown("not set"))
    var prepareAutoCloseChangeResult: Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError> = .failure(.unknown("not set"))
    var prepareLimitOrderChangeResult: Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError> = .failure(.unknown("not set"))
    var submitResult: PerpsSubmitResult?
    var reconcileResult: PerpsReconcileResult = .pending

    private(set) var preparedIntents: [PerpsOpenMarketIntent] = []
    private(set) var preparedCloseIntents: [PerpsCloseIntent] = []
    private(set) var preparedSizeChangeIntents: [PerpsSizeChangeIntent] = []
    private(set) var preparedLimitOrderChangeIntents: [PerpsLimitOrderChangeIntent] = []
    private(set) var positionLiquidationPreviews: [Double] = []
    private(set) var previewedIntents: [PerpsOpenMarketIntent] = []

    func openMarketContext(marketId: Int64, side: PerpsModels.PerpsTradeSide) async -> PerpsOpenMarketContext? {
        if failsMarketLoad { return nil }
        return context ?? Self.makeContext(marketId: marketId, side: side)
    }

    func previewOpenMarket(_ intent: PerpsOpenMarketIntent) async -> Result<PerpsOpenOrderReview, PerpsTradingError> {
        previewedIntents.append(intent)
        await previewSuspension?()
        return previewHandler?(intent) ?? previewResult
    }

    func prepareOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsPreparedTradingAction, PerpsTradingError> {
        preparedIntents.append(intent)
        return prepareResult
    }

    func reconcile(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        reconcileResult
    }

    func submit(_ prepared: PerpsPreparedTradingAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        submitResult ?? .failed(.unknown("not set"))
    }

    func previewClose(_: PerpsCloseIntent) async -> Result<PerpsCloseReview, PerpsTradingError> {
        previewCloseResult
    }

    func prepareClose(
        _ intent: PerpsCloseIntent
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError> {
        preparedCloseIntents.append(intent)
        return prepareCloseResult
    }

    func submit(_ prepared: PerpsPreparedCloseAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        submitResult ?? .failed(.unknown("not set"))
    }

    func previewSizeChange(_: PerpsSizeChangeIntent) async -> Result<PerpsSizeChangeReview, PerpsTradingError> {
        previewSizeChangeResult
    }

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> {
        preparedSizeChangeIntents.append(intent)
        return prepareSizeChangeResult
    }

    func submit(_ prepared: PerpsPreparedSizeChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        submitResult ?? .failed(.unknown("not set"))
    }

    func previewMarginChange(_: PerpsMarginChangeIntent) async -> Result<PerpsMarginChangeReview, PerpsTradingError> {
        previewMarginChangeResult
    }

    func prepareMarginChange(
        _: PerpsMarginChangeIntent
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError> {
        return prepareMarginChangeResult
    }

    func submit(_ prepared: PerpsPreparedMarginChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        submitResult ?? .failed(.unknown("not set"))
    }

    func prepareAutoCloseChange(
        _: PerpsAutoCloseChangeIntent
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError> {
        return prepareAutoCloseChangeResult
    }

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        submitResult ?? .failed(.unknown("not set"))
    }

    func prepareLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent
    ) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError> {
        preparedLimitOrderChangeIntents.append(intent)
        return prepareLimitOrderChangeResult
    }

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        submitResult ?? .failed(.unknown("not set"))
    }

    var blockedByPending = Set<Int64>()

    func marketsBlockedByPending() async -> Set<Int64> {
        blockedByPending
    }

    var reviewer = FakePerpetualReviewer()
    private(set) var reviewerLoads = 0
    private(set) var reviewerIntents = [PerpsOpenMarketIntent]()

    func loadReviewer(for intent: PerpsOpenMarketIntent) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        reviewerLoads += 1
        reviewerIntents.append(intent)
        return .success(reviewer)
    }

    func loadReviewer(for _: PerpsMarginChangeIntent) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        reviewerLoads += 1
        return .success(reviewer)
    }

    var marginLimits: Result<PerpsMarginChangeLimits, PerpsTradingError> = .failure(.unknown("not set"))

    func marginChangeLimits(marketId _: Int64) async -> Result<PerpsMarginChangeLimits, PerpsTradingError> {
        marginLimits
    }

    // MARK: Builders

    static func makeContext(
        marketId: Int64 = 1,
        side: PerpsModels.PerpsTradeSide = .long,
        displayPrice: Double = 66141.70,
        sizeDecimals: Int = 5,
        minNotionalUsd: Double = 0
    ) -> PerpsOpenMarketContext {
        PerpsOpenMarketContext(
            marketId: marketId,
            side: side,
            symbol: "BTC",
            displayPrice: displayPrice,
            priceDecimals: 2,
            sizeDecimals: sizeDecimals,
            leverageBounds: PerpsLeverageBounds(min: 1, max: 40),
            defaultLeverage: 27,
            maxSlippage: 0.01,
            minBaseSize: 0.0001,
            minNotionalUsd: minNotionalUsd
        )
    }

    static func makeIntent(
        marginUsd: String = "20",
        leverage: Double = 27,
        autoClose: PerpsAutoClose? = nil,
        limitPrice: Double? = nil
    ) -> PerpsOpenMarketIntent {
        PerpsOpenMarketIntent(marketId: 1, side: .long, marginUsd: marginUsd, leverage: leverage, maxSlippage: 0.01, autoClose: autoClose, limitPrice: limitPrice)
    }

    static func makeConfirmContext(
        intent: PerpsOpenMarketIntent? = nil,
        review: PerpsOpenOrderReview? = nil
    ) -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: intent ?? makeIntent(),
            sizeDecimals: 5,
            priceDecimals: 2,
            review: review ?? makeReview()
        )
    }

    static func makeCloseReview(
        side: PerpsModels.PerpsTradeSide = .long,
        leverage: Double? = 27,
        marginUsd: Double = 20,
        notionalUsd: Double = 540,
        baseSize: Double = 0.00781,
        estimatedFeeUsd: Double? = 0.144,
        estimatedPnlUsd: Double? = 0.5,
        estimatedReceiveUsd: Double? = 20.34
    ) -> PerpsCloseReview {
        PerpsCloseReview(
            symbol: "BTC",
            side: side,
            leverage: leverage,
            marginUsd: marginUsd,
            notionalUsd: notionalUsd,
            baseSize: baseSize,
            estimatedFeeUsd: estimatedFeeUsd,
            estimatedPnlUsd: estimatedPnlUsd,
            estimatedReceiveUsd: estimatedReceiveUsd
        )
    }

    static func makeSizeChangeReview(
        direction: PerpsSizeChangeDirection = .add,
        side: PerpsModels.PerpsTradeSide = .long,
        leverage: Double? = 27,
        marginDeltaUsd: Double = 20,
        entryPrice: PerpsValueChange = PerpsValueChange(old: 66541.70, new: 66021.17),
        notionalUsd: PerpsValueChange = PerpsValueChange(old: 540, new: 1080),
        baseSize: PerpsValueChange = PerpsValueChange(old: 0.008, new: 0.0163),
        liquidationPrice: PerpsValueChange? = PerpsValueChange(old: 64141.75, new: 63200),
        estimatedFeeUsd: Double? = 0.144
    ) -> PerpsSizeChangeReview {
        PerpsSizeChangeReview(
            symbol: "BTC",
            direction: direction,
            side: side,
            leverage: leverage,
            marginDeltaUsd: marginDeltaUsd,
            entryPrice: entryPrice,
            notionalUsd: notionalUsd,
            baseSize: baseSize,
            liquidationPrice: liquidationPrice,
            liquidationUnavailableReason: liquidationPrice == nil ? .missingMark : nil,
            estimatedFeeUsd: estimatedFeeUsd
        )
    }

    @MainActor
    static func makeReviewingSizeChangeSession(
        review: PerpsSizeChangeReview = makeSizeChangeReview(),
        autoClose: PerpsAutoClose? = nil
    ) -> PerpsSizeChangeSession {
        let session = PerpsSizeChangeSession(
            marketId: 1,
            direction: review.direction,
            priceDecimals: 2,
            restingTriggerOrders: makeTriggerOrders(
                autoClose: autoClose,
                side: review.side,
                baseAmount: review.baseSize.old
            )
        )
        session.setAmount(PerpsDecimalInput.usdText(review.marginDeltaUsd))
        guard let request = session.beginPreparation() else {
            preconditionFailure("size-change fixture must start preparation")
        }
        let prepared = PerpsPreparedSizeChangeAction(
            operationId: "prepared",
            walletId: "wallet",
            marketId: 1,
            intent: request.intent,
            review: review,
            normalizedAutoClose: nil
        )
        guard session.acceptPreparation(prepared, for: request) else {
            preconditionFailure("size-change fixture must accept preparation")
        }
        return session
    }

    static func makeTriggerOrders(
        autoClose: PerpsAutoClose?,
        side: PerpsModels.PerpsTradeSide,
        baseAmount: Double
    ) -> [PerpsTriggerOrderSummary] {
        let closeSide: PerpsModels.PerpsTradeSide = side == .long ? .short : .long
        var orders: [PerpsTriggerOrderSummary] = []
        if let takeProfit = autoClose?.takeProfit {
            orders.append(PerpsTriggerOrderSummary(
                orderIndex: 1,
                kind: .takeProfit,
                side: closeSide,
                triggerPrice: takeProfit.triggerPrice,
                baseAmount: baseAmount
            ))
        }
        if let stopLoss = autoClose?.stopLoss {
            orders.append(PerpsTriggerOrderSummary(
                orderIndex: 2,
                kind: .stopLoss,
                side: closeSide,
                triggerPrice: stopLoss.triggerPrice,
                baseAmount: baseAmount
            ))
        }
        return orders
    }

    static func makeMarginChangeReview(
        direction: PerpsMarginChangeDirection = .add,
        side: PerpsModels.PerpsTradeSide = .long,
        leverage: Double? = 27,
        amountUsd: Double = 20,
        allocatedMargin: PerpsValueChange = PerpsValueChange(old: 20.5, new: 40.5),
        liquidationPrice: PerpsValueChange? = PerpsValueChange(old: 64141.75, new: 63639.99),
        isImmediateRisk: Bool = false
    ) -> PerpsMarginChangeReview {
        PerpsMarginChangeReview(
            symbol: "BTC",
            direction: direction,
            side: side,
            leverage: leverage,
            amountUsd: amountUsd,
            allocatedMargin: allocatedMargin,
            liquidationPrice: liquidationPrice,
            liquidationUnavailableReason: liquidationPrice == nil ? .missingMark : nil,
            isImmediateRisk: isImmediateRisk
        )
    }

    static func makeReview(
        marginUsd: Double = 20,
        entryPrice: Double? = 66541.70,
        liquidationPrice: Double? = 64141.75,
        notionalUsd: Double = 540,
        baseSize: Double = 0.008115,
        estimatedFeeUsd: Double? = 0.27
    ) -> PerpsOpenOrderReview {
        PerpsOpenOrderReview(
            symbol: "BTC",
            marginUsd: marginUsd,
            entryPrice: entryPrice,
            liquidationPrice: liquidationPrice,
            notionalUsd: notionalUsd,
            baseSize: baseSize,
            estimatedFeeUsd: estimatedFeeUsd,
            liquidationUnavailableReason: liquidationPrice == nil ? .missingMark : nil
        )
    }
}

final class FakePerpetualReviewer: PerpetualReviewer, @unchecked Sendable {
    var isStale = false
    var openReview: PerpsOpenOrderReview?
    var minimumOpenMargin: Double?
    var marginReview: PerpsMarginChangeReview?

    func reviewOpen(_: PerpsOpenMarketIntent) -> PerpsOpenOrderReview? {
        openReview
    }

    func minimumOpenMarginUsd(_: PerpsOpenMarketIntent) -> Double? {
        minimumOpenMargin
    }

    func reviewMarginChange(_: PerpsMarginChangeIntent) -> PerpsMarginChangeReview? {
        marginReview
    }
}
