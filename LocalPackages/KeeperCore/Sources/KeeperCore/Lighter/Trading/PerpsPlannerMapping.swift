import ChainKit
import Foundation
import TKPerpsAPI

enum PerpsScaled {
    static func parse(_ decimal: String, decimals: Int32) throws -> Int64 {
        try PerpsFixedPoint.shared.parse(decimal: decimal, decimals: decimals)
    }

    static func scale(_ value: Double, decimals: Int32) throws -> Int64 {
        guard value.isFinite, value >= 0 else {
            throw PerpsTradingError.validation("value is not representable: \(value)")
        }
        return try parse(
            String(
                format: "%.\(decimals)f",
                locale: Locale(identifier: "en_US_POSIX"),
                value
            ),
            decimals: decimals
        )
    }

    static func double(_ value: Int64, decimals: Int32) -> Double {
        Double(value) / pow(10, Double(decimals))
    }

    static func optionalDouble(_ value: KotlinLong?, decimals: Int32) -> Double? {
        value.map { double($0.int64Value, decimals: decimals) }
    }

    static func decimalString(_ value: Int64, decimals: Int32, maxFractionDigits: Int = 8) -> String {
        let negative = value < 0
        let magnitude = value.magnitude
        let digits = String(magnitude).padLeft(to: Int(decimals) + 1, with: "0")
        let split = digits.index(digits.endIndex, offsetBy: -Int(decimals))
        var fraction = String(digits[split...])
        let whole = String(digits[..<split])
        if fraction.count > maxFractionDigits {
            fraction = String(fraction.prefix(maxFractionDigits))
        }
        while fraction.hasSuffix("0") {
            fraction.removeLast()
        }
        if magnitude > 0, whole == "0", fraction.isEmpty {
            fraction = String(repeating: "0", count: max(maxFractionDigits, 1) - 1) + "1"
        }
        let body = fraction.isEmpty ? whole : "\(whole).\(fraction)"
        return negative ? "-\(body)" : body
    }

    static func ppm(percent: String) throws -> Int64 {
        let scaled = try parse(percent, decimals: 10)
        let divisor: Int64 = 1_000_000
        return scaled / divisor + (scaled % divisor == 0 ? 0 : 1)
    }

    static func feeRate(takerPpm: Int64) -> String {
        decimalString(takerPpm, decimals: 6, maxFractionDigits: 8)
    }
}

private extension String {
    func padLeft(to count: Int, with character: Character) -> String {
        if self.count >= count { return self }
        return String(repeating: String(character), count: count - self.count) + self
    }
}

enum PerpsPlannerMapping {
    static let quoteAsset = "USDC"
    private static func pow10(_ decimals: Int32) -> Int64 {
        Int64(pow(10.0, Double(decimals)))
    }

    static let venue = "lighter"
    // Product defaults copied from the custodial perps reference client; update them with that reference.
    static let priceSlippagePpm: Int64 = 10000
    static let tpslPriceSlippagePpm: Int64 = 30000
    static let tpslBufferPpm: Int64 = 2000

    static func freshnessPolicy() -> PerpsFreshnessPolicy {
        PerpsFreshnessPolicy(
            maxRulesAgeUnixMs: 60000,
            maxAccountSnapshotAgeUnixMs: 60000,
            maxMarketSnapshotAgeUnixMs: 60000,
            maxMarkAgeUnixMs: 60000,
            maxTriggerMarkAgeUnixMs: 15000,
            maxFutureSkewUnixMs: 5000,
            planLifetimeUnixMs: 120_000
        )
    }

    static func nowUnixMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    static func slippagePpm(_ fraction: Double) -> Int64 {
        Int64((fraction * 1_000_000).rounded())
    }

    /// Rounds the margin fraction up, never down: rounding down would hand back more
    /// leverage than was asked for and move the liquidation price closer than reviewed.
    /// Reading a venue leverage back uses the same direction so a setting we wrote
    /// compares equal to what the venue reports.
    static func initialMarginBps(leverage: Double) -> Int32 {
        let bps = (10000.0 / max(leverage, 1)).rounded(.up)
        return Int32(min(max(bps, 1), 10000))
    }

    private static let clientOrderIndexAllocator = PerpsClientOrderIndexAllocator()
    private static let ephemeralClientOrderIndexLock = NSLock()
    private static var lastEphemeralClientOrderIndex: Int64?

    static func clientOrderIndex(nowUnixMs: Int64, persistent: Bool = true) throws -> Int64 {
        guard persistent else {
            let minimum = LighterConstants.shared.MinClientOrderIndex
            let maximum = LighterConstants.shared.MaxClientOrderIndex
            let candidate = max(nowUnixMs % maximum, minimum)
            ephemeralClientOrderIndexLock.lock()
            defer { ephemeralClientOrderIndexLock.unlock() }
            let next = max(candidate, (lastEphemeralClientOrderIndex ?? minimum - 1) + 1)
            guard next < maximum else {
                throw PerpsTradingError.protocolFailure("client order index exhausted")
            }
            lastEphemeralClientOrderIndex = next
            return next
        }
        return try clientOrderIndexAllocator.next(nowUnixMs: nowUnixMs)
    }

    static func orderRefs(_ step: PerpsSignedStep) -> [PerpsPendingOrderRef] {
        step.orders.compactMap { order in
            guard order.clientOrderIndex > 0, let role = pendingRole(order.role) else { return nil }
            return PerpsPendingOrderRef(role: role, clientOrderIndex: order.clientOrderIndex)
        }
    }

    static func pendingRole(_ role: PerpsOrderRole) -> PerpsPendingOrderRole? {
        if role == PerpsOrderRole.parent { return .parent }
        if role == PerpsOrderRole.takeprofit { return .takeProfit }
        if role == PerpsOrderRole.stoploss { return .stopLoss }
        if role == PerpsOrderRole.close { return .close }
        if role == PerpsOrderRole.add { return .add }
        return nil
    }

    static func positionId(marketId: Int64) -> String {
        "\(marketId)"
    }

    static func tkPositionId(marketId: Int64) -> String {
        "\(venue):\(marketId)"
    }

    static func side(_ side: PerpsTradeSide) -> PerpsSide {
        switch side {
        case .long: PerpsSide.long_
        case .short: PerpsSide.short_
        }
    }

    static func tradeSide(_ side: PerpsSide) -> PerpsTradeSide {
        side === PerpsSide.short_ ? .short : .long
    }

    static func bookSide(_ side: PerpsSide) -> Operations.getTruncatedOrderBook.Input.Query.sidePayload {
        side === PerpsSide.short_ ? .sell : .buy
    }

    static let minAdjustMarginUsd = "1"

    static func rules(
        market: Components.Schemas.Market,
        environment: String,
        receivedAtUnixMs: Int64
    ) throws -> PerpsMarketRules {
        guard let marketId = market.market_index.map(Int64.init) else {
            throw PerpsTradingError.validation("market index is missing")
        }
        guard let priceDecimals = market.price_decimals.map(Int32.init),
              let baseDecimals = market.size_decimals.map(Int32.init)
        else {
            throw PerpsTradingError.validation("market decimals are missing")
        }
        guard let status = market.status, !status.isEmpty else {
            throw PerpsTradingError.validation("market status is missing")
        }
        let quoteDecimals = priceDecimals + baseDecimals
        let minAdjustMarginQuote = try PerpsScaled.parse(minAdjustMarginUsd, decimals: quoteDecimals)
        let scale = PerpsScale(
            priceDecimals: priceDecimals,
            baseDecimals: baseDecimals,
            quoteDecimals: quoteDecimals
        )
        let tick = try parseRequired(market.tick_size, decimals: priceDecimals, field: "tick_size")
        let step = try parseRequired(market.step_size, decimals: baseDecimals, field: "step_size")
        let minBase = try parseRequired(market.min_size_base, decimals: baseDecimals, field: "min_size_base")
        let maxBase = try parseOptional(market.max_size_base, decimals: baseDecimals)
        let minNotional = try parseOptional(market.min_size_quote, decimals: quoteDecimals)
        let maxNotional = try parseOptional(market.max_size_quote, decimals: quoteDecimals)
        let makerPpm = try ppm(market.maker_fee_pct, field: "maker_fee_pct")
        let takerPpm = try ppm(market.taker_fee_pct, field: "taker_fee_pct")
        guard let initialMargin = market.initial_margin_fraction else {
            throw PerpsTradingError.validation("initial_margin_fraction is missing")
        }
        let maxInitial: Int32 = 10000
        guard let maintenanceMargin = market.maintenance_margin_fraction else {
            throw PerpsTradingError.validation("maintenance_margin_fraction is missing")
        }
        let minInitial = Int32(initialMargin)
        let maintenance = Int32(maintenanceMargin)
        let closeout = market.closeout_margin_fraction.map { KotlinInt(value: Int32($0)) }
        return PerpsMarketRules(
            scopeEnvironment: environment,
            marketId: marketId,
            quoteAsset: market.quote_asset ?? quoteAsset,
            tradingStatus: status,
            scale: scale,
            priceTick: tick,
            baseStep: step,
            minBaseAmount: minBase,
            maxBaseAmount: maxBase,
            minNotionalQuote: minNotional,
            maxNotionalQuote: maxNotional,
            makerFeePpm: makerPpm,
            takerFeePpm: takerPpm,
            minInitialMarginBps: minInitial,
            maxInitialMarginBps: max(maxInitial, minInitial),
            maintenanceMarginBps: maintenance,
            closeoutMarginBps: closeout,
            priceSlippagePpm: priceSlippagePpm,
            tpslPriceSlippagePpm: tpslPriceSlippagePpm,
            tpslBufferPpm: tpslBufferPpm,
            minAdjustMarginQuote: minAdjustMarginQuote,
            integrator: PerpsIntegratorFees.companion.NONE,
            freshness: PerpsFreshness(receivedAtUnixMs: receivedAtUnixMs, sourceUpdatedAtUnixMs: nil)
        )
    }

    static func context(
        scope: PerpsScope,
        marketId: Int64,
        screen: Components.Schemas.TradingScreen,
        rules: PerpsMarketRules,
        receivedAtUnixMs: Int64,
        restingOrders: [PerpsRestingOrder]
    ) throws -> PerpetualAccountSnapshot {
        let available = try parseOptional(
            screen.balance?.available_balance,
            decimals: rules.scale.quoteDecimals
        )?.int64Value ?? 0
        let position = try positionState(screen.position?.value1, rules: rules, marketId: marketId)
        let openEnabled = screen.flags?.open_enabled ?? false
        let marginSettings: PerpsMarginSettings
        if let position = screen.position?.value1, let leverage = position.leverage, leverage > 0 {
            let mode: Int32 = position.margin_mode == .cross
                ? 0
                : LighterConstants.shared.IsolatedMargin
            marginSettings = PerpsMarginSettings.Known(
                mode: mode,
                initialMarginBps: initialMarginBps(leverage: Double(leverage))
            )
        } else {
            marginSettings = PerpsMarginSettings.Unknown.shared
        }
        return PerpetualAccountSnapshot(
            scope: scope,
            marketId: marketId,
            freshness: PerpsFreshness(receivedAtUnixMs: receivedAtUnixMs, sourceUpdatedAtUnixMs: nil),
            completeness: screen.open_orders != nil && PerpsBackendMapping.ordersVisible(screen.flags)
                ? PerpsContextCompleteness.Complete.shared
                : PerpsContextCompleteness.Incomplete(reason: "open orders are unavailable"),
            openEnabled: openEnabled,
            availableBalanceQuote: available,
            position: position,
            restingOrders: restingOrders,
            marginSettings: marginSettings
        )
    }

    static func restingOrders(
        _ orders: [Components.Schemas.Order]?,
        rules: PerpsMarketRules
    ) throws -> [PerpsRestingOrder] {
        guard let orders else { return [] }
        return try orders.compactMap { order in
            guard let index = order.order_index else { return nil }
            let side: PerpsSide = order.side == .short ? .short_ : .long_
            let remaining = try remainingBase(order, decimals: rules.scale.baseDecimals)
            return try PerpsRestingOrder(
                orderIndex: index,
                clientOrderIndex: order.client_order_index.map { KotlinLong(value: $0) },
                side: side,
                category: category(order.category),
                orderType: orderType(order._type, category: order.category),
                status: status(order.status),
                reduceOnly: order.reduce_only
                    ?? (order.category == .take_profit || order.category == .stop_loss || order.category == .close),
                positionTied: order.category == .take_profit || order.category == .stop_loss,
                remainingBaseAmount: remaining,
                limitPrice: parseOptional(order.price, decimals: rules.scale.priceDecimals),
                triggerPrice: parseOptional(order.trigger_price, decimals: rules.scale.priceDecimals),
                expiryUnixMs: order.expires_at.map { KotlinLong(value: Int64($0.timeIntervalSince1970 * 1000)) }
            )
        }
    }

    struct SnapshotNeed {
        let side: PerpsSide?
        let coverageQuote: Int64
        let includeMark: Bool
    }

    static func snapshotNeed(intent: PerpsTradeIntent, context: PerpsMarketContext) -> SnapshotNeed {
        let mark = context.mark?.price ?? 0
        let quoteScale = pow10(context.rules.scale.quoteDecimals)
        let baseScale = pow10(context.rules.scale.baseDecimals)
        func notional(_ base: Int64) -> Int64 {
            guard base > 0, mark > 0 else { return quoteScale }
            let value = Double(base) * Double(mark) / Double(baseScale)
            return max(quoteScale, Int64(min(value * 2.0, Double(Int64.max))))
        }
        switch intent {
        case let open as PerpsTradeIntent.Open:
            let side: PerpsSide? = open.order is PerpsOrderSpec.Market ? open.side : nil
            let notional = Double(open.marginBudgetQuote) * 10000.0 / Double(max(open.initialMarginBps, 1)) * 2.0
            return SnapshotNeed(side: side, coverageQuote: max(quoteScale, Int64(min(notional, Double(Int64.max)))), includeMark: true)
        case let add as PerpsTradeIntent.Add:
            let side: PerpsSide? = add.order is PerpsOrderSpec.Market ? add.side : nil
            let notional = Double(add.marginBudgetQuote) * 10000.0 / Double(max(add.initialMarginBps, 1)) * 2.0
            return SnapshotNeed(side: side, coverageQuote: max(quoteScale, Int64(min(notional, Double(Int64.max)))), includeMark: true)
        case let close as PerpsTradeIntent.Close:
            return SnapshotNeed(side: close.side === PerpsSide.long_ ? .short_ : .long_, coverageQuote: notional((close.baseAmount ?? KotlinLong(value: close.positionBaseAmount))?.int64Value ?? close.positionBaseAmount), includeMark: true)
        case is PerpsTradeIntent.AutoClose, is PerpsTradeIntent.Margin, is PerpsTradeIntent.OrderModify:
            return SnapshotNeed(side: nil, coverageQuote: quoteScale, includeMark: true)
        case is PerpsTradeIntent.OrderCancel:
            return SnapshotNeed(side: nil, coverageQuote: 0, includeMark: false)
        default:
            return SnapshotNeed(side: nil, coverageQuote: quoteScale, includeMark: true)
        }
    }

    static func marketSnapshot(
        side: PerpsSide,
        coverageQuote: Int64,
        book: Components.Schemas.TruncatedOrderBook,
        mark: PerpsMarkPrice?,
        marketId: Int64,
        rules: PerpsMarketRules,
        environment: String,
        receivedAtUnixMs: Int64
    ) throws -> PerpetualMarketSnapshot {
        let levelsSource = side === PerpsSide.short_ ? book.bids : book.asks
        let levels = try (levelsSource ?? []).map { level in
            try PerpsBookLevel(
                price: parseRequired(level.price, decimals: rules.scale.priceDecimals, field: "book.price"),
                baseAmount: parseRequired(level.size, decimals: rules.scale.baseDecimals, field: "book.size")
            )
        }
        let sourceUpdated = Int64(book.updated_at.timeIntervalSince1970 * 1000)
        return PerpetualMarketSnapshot(
            snapshotId: UUID().uuidString,
            marketId: marketId,
            environment: environment,
            receivedAtUnixMs: receivedAtUnixMs,
            sourceUpdatedAtUnixMs: KotlinLong(value: sourceUpdated),
            book: PerpsBookSlice(
                side: side,
                levels: levels,
                truncatedAtCoverage: book.truncated,
                requestedCoverageQuote: coverageQuote,
                requestedCoverageBaseAmount: nil
            ),
            mark: mark
        )
    }

    static func markSnapshot(
        marketId: Int64,
        environment: String,
        mark: PerpsMarkPrice?,
        receivedAtUnixMs: Int64
    ) -> PerpetualMarketSnapshot {
        PerpetualMarketSnapshot(
            snapshotId: UUID().uuidString,
            marketId: marketId,
            environment: environment,
            receivedAtUnixMs: receivedAtUnixMs,
            sourceUpdatedAtUnixMs: mark.map { KotlinLong(value: $0.observedAtUnixMs) },
            book: nil,
            mark: mark
        )
    }

    static func markPrice(
        _ decimal: String?,
        live: Double?,
        decimals: Int32,
        nowUnixMs: Int64
    ) throws -> PerpsMarkPrice? {
        if let live, live > 0, let scaled = try? PerpsScaled.scale(live, decimals: decimals), scaled > 0 {
            return PerpsMarkPrice(price: scaled, observedAtUnixMs: nowUnixMs)
        }
        guard let decimal else { return nil }
        return try PerpsMarkPrice(
            price: PerpsScaled.parse(decimal, decimals: decimals),
            observedAtUnixMs: nowUnixMs
        )
    }

    static func openReview(
        _ review: PerpetualReview.Open,
        symbol: String,
        marginUsd: Double
    ) -> PerpsOpenOrderReview {
        let decimals = review.scale
        return PerpsOpenOrderReview(
            symbol: symbol,
            marginUsd: marginUsd,
            entryPrice: PerpsScaled.double(review.estimatedEntryPrice, decimals: decimals.priceDecimals),
            liquidationPrice: PerpsScaled.optionalDouble(review.liquidationPrice, decimals: decimals.priceDecimals),
            notionalUsd: PerpsScaled.double(review.notionalQuote, decimals: decimals.quoteDecimals),
            baseSize: PerpsScaled.double(review.baseAmount, decimals: decimals.baseDecimals),
            estimatedFeeUsd: PerpsScaled.double(review.estimatedFeeQuote, decimals: decimals.quoteDecimals),
            liquidationUnavailableReason: review.liquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil
        )
    }

    static func closeReview(
        _ review: PerpetualReview.Close,
        symbol: String,
        leverage: Double?
    ) -> PerpsCloseReview {
        let decimals = review.scale
        return PerpsCloseReview(
            symbol: symbol,
            side: tradeSide(review.side),
            leverage: leverage,
            marginUsd: PerpsScaled.double(review.estimatedReturnedMarginQuote, decimals: decimals.quoteDecimals),
            notionalUsd: PerpsScaled.double(review.notionalQuote, decimals: decimals.quoteDecimals),
            baseSize: PerpsScaled.double(review.estimatedFillBaseAmount, decimals: decimals.baseDecimals),
            estimatedFeeUsd: PerpsScaled.double(review.estimatedFeeQuote, decimals: decimals.quoteDecimals),
            estimatedPnlUsd: PerpsScaled.double(review.estimatedRealizedPnlQuote, decimals: decimals.quoteDecimals),
            estimatedReceiveUsd: PerpsScaled.double(review.estimatedReceiveQuote, decimals: decimals.quoteDecimals)
        )
    }

    static func addReview(
        _ review: PerpetualReview.Add,
        symbol: String,
        direction: PerpsSizeChangeDirection,
        marginDeltaUsd: Double,
        oldBase: Int64,
        oldEntry: Int64,
        oldNotionalUsd: Double
    ) -> PerpsSizeChangeReview {
        let decimals = review.scale
        return PerpsSizeChangeReview(
            symbol: symbol,
            direction: direction,
            side: tradeSide(review.side),
            leverage: Double(review.initialMarginBps) > 0
                ? (10000.0 / Double(review.initialMarginBps)).rounded()
                : nil,
            marginDeltaUsd: marginDeltaUsd,
            entryPrice: PerpsValueChange(
                old: PerpsScaled.double(oldEntry, decimals: decimals.priceDecimals),
                new: PerpsScaled.double(review.mergedEntryPrice, decimals: decimals.priceDecimals)
            ),
            notionalUsd: PerpsValueChange(
                old: oldNotionalUsd,
                new: PerpsScaled.double(review.mergedBaseAmount, decimals: decimals.baseDecimals)
                    * PerpsScaled.double(review.mergedEntryPrice, decimals: decimals.priceDecimals)
            ),
            baseSize: PerpsValueChange(
                old: PerpsScaled.double(oldBase, decimals: decimals.baseDecimals),
                new: PerpsScaled.double(review.mergedBaseAmount, decimals: decimals.baseDecimals)
            ),
            liquidationPrice: PerpsScaled.optionalDouble(review.liquidationPrice, decimals: decimals.priceDecimals),
            liquidationUnavailableReason: review.liquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil,
            estimatedFeeUsd: PerpsScaled.double(review.estimatedFeeQuote, decimals: decimals.quoteDecimals)
        )
    }

    static func closeSizeReview(
        _ review: PerpetualReview.Close,
        symbol: String,
        direction: PerpsSizeChangeDirection,
        marginDeltaUsd: Double,
        leverage: Double?,
        oldBase: Int64,
        oldEntry: Int64,
        oldNotionalUsd: Double
    ) -> PerpsSizeChangeReview {
        let decimals = review.scale
        return PerpsSizeChangeReview(
            symbol: symbol,
            direction: direction,
            side: tradeSide(review.side),
            leverage: leverage,
            marginDeltaUsd: marginDeltaUsd,
            entryPrice: PerpsValueChange(
                old: PerpsScaled.double(oldEntry, decimals: decimals.priceDecimals),
                new: PerpsScaled.double(oldEntry, decimals: decimals.priceDecimals)
            ),
            notionalUsd: PerpsValueChange(
                old: oldNotionalUsd,
                new: PerpsScaled.double(review.remainingBaseAmount, decimals: decimals.baseDecimals)
                    * PerpsScaled.double(oldEntry, decimals: decimals.priceDecimals)
            ),
            baseSize: PerpsValueChange(
                old: PerpsScaled.double(oldBase, decimals: decimals.baseDecimals),
                new: PerpsScaled.double(review.remainingBaseAmount, decimals: decimals.baseDecimals)
            ),
            liquidationPrice: PerpsScaled.optionalDouble(review.liquidationPrice, decimals: decimals.priceDecimals),
            liquidationUnavailableReason: review.liquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil,
            estimatedFeeUsd: PerpsScaled.double(review.estimatedFeeQuote, decimals: decimals.quoteDecimals)
        )
    }

    static func marginReview(
        _ review: PerpetualReview.Margin,
        symbol: String,
        direction: PerpsMarginChangeDirection,
        side: PerpsTradeSide,
        leverage: Double?,
        allocatedBefore: Int64,
        liquidationBefore: Int64?
    ) -> PerpsMarginChangeReview {
        let decimals = review.scale
        let after = review.allocatedMarginAfterQuote
        let liquidationAfter = PerpsScaled.optionalDouble(review.liquidationPrice, decimals: decimals.priceDecimals)
        let liquidationChange: PerpsValueChange? = liquidationAfter.map { new in
            PerpsValueChange(
                old: liquidationBefore.map { PerpsScaled.double($0, decimals: decimals.priceDecimals) } ?? new,
                new: new
            )
        }
        return PerpsMarginChangeReview(
            symbol: symbol,
            direction: direction,
            side: side,
            leverage: leverage,
            amountUsd: PerpsScaled.double(review.amountQuote, decimals: decimals.quoteDecimals),
            allocatedMargin: PerpsValueChange(
                old: PerpsScaled.double(allocatedBefore, decimals: decimals.quoteDecimals),
                new: PerpsScaled.double(after, decimals: decimals.quoteDecimals)
            ),
            liquidationPrice: liquidationChange,
            liquidationUnavailableReason: review.liquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil,
            isImmediateRisk: review.isImmediateRisk
        )
    }

    static func autoCloseReview(
        _ review: PerpetualReview.AutoClose,
        scale: PerpsScale
    ) -> PerpsAutoCloseChangeReview {
        let takeProfit = PerpsScaled.optionalDouble(review.takeProfitTrigger, decimals: scale.priceDecimals)
            .map(PerpsAutoCloseTrigger.init(triggerPrice:))
        let stopLoss = PerpsScaled.optionalDouble(review.stopLossTrigger, decimals: scale.priceDecimals)
            .map(PerpsAutoCloseTrigger.init(triggerPrice:))
        let target = (takeProfit == nil && stopLoss == nil)
            ? nil
            : PerpsAutoClose(takeProfit: takeProfit, stopLoss: stopLoss)
        return PerpsAutoCloseChangeReview(side: tradeSide(review.side), new: target)
    }
}

private extension PerpsPlannerMapping {
    static func parseRequired(_ value: String?, decimals: Int32, field: String) throws -> Int64 {
        guard let value, !value.isEmpty else {
            throw PerpsTradingError.validation("\(field) is missing")
        }
        do {
            return try PerpsScaled.parse(value, decimals: decimals)
        } catch {
            throw PerpsTradingError.validation("\(field) is not a valid decimal")
        }
    }

    static func parseOptional(_ value: String?, decimals: Int32) throws -> KotlinLong? {
        guard let value, !value.isEmpty else { return nil }
        return try KotlinLong(value: PerpsScaled.parse(value, decimals: decimals))
    }

    static func ppm(_ percent: String?, field: String) throws -> Int64 {
        guard let percent, !percent.isEmpty else {
            throw PerpsTradingError.validation("\(field) is missing")
        }
        do {
            return try PerpsScaled.ppm(percent: percent)
        } catch {
            throw PerpsTradingError.validation("\(field) is not a valid fee")
        }
    }

    static func positionState(
        _ position: Components.Schemas.Position?,
        rules: PerpsMarketRules,
        marketId: Int64
    ) throws -> PerpsPositionState {
        guard let position, let size = position.size, !size.isEmpty else {
            return PerpsPositionState.KnownFlat.shared
        }
        let base = try PerpsScaled.parse(size, decimals: rules.scale.baseDecimals)
        guard base > 0 else { return PerpsPositionState.KnownFlat.shared }
        let side: PerpsSide = position.side == .short ? .short_ : .long_
        let entry = try parseRequired(position.avg_entry_price, decimals: rules.scale.priceDecimals, field: "avg_entry_price")
        let margin = try parseRequired(position.allocated_margin, decimals: rules.scale.quoteDecimals, field: "allocated_margin")
        return try PerpsPositionState.Present(
            positionId: positionId(marketId: marketId),
            side: side,
            baseAmount: base,
            entryPrice: entry,
            allocatedMarginQuote: margin,
            liquidationPrice: parseOptional(position.liquidation_price, decimals: rules.scale.priceDecimals)
        )
    }

    static func remainingBase(_ order: Components.Schemas.Order, decimals: Int32) throws -> Int64 {
        let base = try parseOptional(order.base_size, decimals: decimals)?.int64Value ?? 0
        let filled = try parseOptional(order.filled_base, decimals: decimals)?.int64Value ?? 0
        return max(0, base - filled)
    }

    static func category(_ value: Components.Schemas.OrderCategory?) -> PerpsOrderCategory {
        switch value {
        case .close: .close
        case .take_profit: .takeprofit
        case .stop_loss: .stoploss
        case .liquidation: .liquidation
        default: .open
        }
    }

    static func orderType(
        _ value: Components.Schemas.OrderType?,
        category: Components.Schemas.OrderCategory?
    ) -> PerpsRestingOrderType {
        switch category {
        case .take_profit: .takeprofit
        case .stop_loss: .stoploss
        case .liquidation: .liquidation
        default:
            value == .market ? .market : .limit
        }
    }

    static func status(_ value: Components.Schemas.OrderStatus?) -> PerpsRestingOrderStatus {
        switch value {
        case .new: .pending
        case .open, .partially_filled: .open
        case .filled: .filled
        case .canceled, .rejected: .canceled
        case .none: .open
        }
    }
}
