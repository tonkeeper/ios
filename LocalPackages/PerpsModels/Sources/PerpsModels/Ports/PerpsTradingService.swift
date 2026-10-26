import Foundation

public protocol PerpsTradingService: AnyObject, Sendable {
    func openMarketContext(marketId: Int64, side: PerpsTradeSide) async -> PerpsOpenMarketContext?

    func previewOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsOpenOrderReview, PerpsTradingError>

    func prepareOpenMarket(
        _ intent: PerpsOpenMarketIntent
    ) async -> Result<PerpsPreparedTradingAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedTradingAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult

    func reconcile(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult

    func previewClose(
        _ intent: PerpsCloseIntent
    ) async -> Result<PerpsCloseReview, PerpsTradingError>

    func prepareClose(
        _ intent: PerpsCloseIntent
    ) async -> Result<PerpsPreparedCloseAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedCloseAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult

    func previewSizeChange(
        _ intent: PerpsSizeChangeIntent
    ) async -> Result<PerpsSizeChangeReview, PerpsTradingError>

    func prepareSizeChange(
        _ intent: PerpsSizeChangeIntent
    ) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedSizeChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult

    func previewMarginChange(
        _ intent: PerpsMarginChangeIntent
    ) async -> Result<PerpsMarginChangeReview, PerpsTradingError>

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent
    ) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedMarginChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult

    func prepareAutoCloseChange(
        _ intent: PerpsAutoCloseChangeIntent
    ) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedAutoCloseChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult

    func prepareLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent
    ) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError>

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult

    func marketsBlockedByPending() async -> Set<Int64>

    /// Reads the market once and hands back something that reviews trades over that
    /// read, synchronously. Submitting re-plans from a fresh read of its own, so a
    /// reviewer shows figures and never sends them.
    func loadReviewer(for intent: PerpsOpenMarketIntent) async -> Result<any PerpetualReviewer, PerpsTradingError>

    func loadReviewer(for intent: PerpsMarginChangeIntent) async -> Result<any PerpetualReviewer, PerpsTradingError>

    func marginChangeLimits(marketId: Int64) async -> Result<PerpsMarginChangeLimits, PerpsTradingError>
}
