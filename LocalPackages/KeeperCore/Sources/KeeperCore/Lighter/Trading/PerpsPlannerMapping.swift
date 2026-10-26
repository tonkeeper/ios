import ChainKit
import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

enum PerpsScaled {
    /// Which way a value moves when the market's scale cannot hold all of it. A bound
    /// rounds away from what it bounds — a minimum up, a maximum down — so a request
    /// the venue would refuse is not let through here; money we might spend rounds
    /// down, so we never claim more than there is; everything else goes to the nearest
    /// value the scale can hold.
    enum Rounding {
        case nearest
        case down
        case up

        var mode: NumberFormatter.RoundingMode {
            switch self {
            case .nearest: .halfUp
            case .down: .down
            case .up: .up
            }
        }
    }

    static func parse(_ decimal: String, decimals: Int32, rounding: Rounding) throws -> Int64 {
        guard let value = Decimal(string: decimal, locale: posixLocale) else {
            throw PerpsTradingError.validation("value is not representable: \(decimal)")
        }
        let formatter = NumberFormatter()
        formatter.locale = posixLocale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.roundingMode = rounding.mode
        formatter.minimumFractionDigits = Int(decimals)
        formatter.maximumFractionDigits = Int(decimals)
        formatter.minimumIntegerDigits = 1
        guard let text = formatter.string(from: NSDecimalNumber(decimal: value)) else {
            throw PerpsTradingError.validation("value is not representable: \(decimal)")
        }
        return try PerpsFixedPoint.shared.parse(decimal: text, decimals: decimals)
    }

    static func scale(_ value: Double, decimals: Int32, rounding: Rounding) throws -> Int64 {
        guard value.isFinite, value >= 0 else {
            throw PerpsTradingError.validation("value is not representable: \(value)")
        }
        return try parse(
            String(format: "%.\(decimals + 6)f", locale: posixLocale, value),
            decimals: decimals,
            rounding: rounding
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
        let scaled = try parse(percent, decimals: 10, rounding: .up)
        let divisor: Int64 = 1_000_000
        return scaled / divisor + (scaled % divisor == 0 ? 0 : 1)
    }

    static func feeRate(takerPpm: Int64) -> String {
        decimalString(takerPpm, decimals: 6, maxFractionDigits: 8)
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")
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
    static let removeMarginBufferPpm: Int64 = 100
    static let minRemoveMarginBufferUsd = "0.01"

    static func freshnessPolicy() -> PerpsFreshnessPolicy {
        PerpsFreshnessPolicy(
            maxRulesAgeUnixMs: 60000,
            maxAccountSnapshotAgeUnixMs: 60000,
            maxMarketSnapshotAgeUnixMs: PerpsServerClock.maxDeviceSkewMs,
            maxMarkAgeUnixMs: 60000,
            maxTriggerMarkAgeUnixMs: 15000,
            maxFutureSkewUnixMs: PerpsServerClock.maxDeviceSkewMs,
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

    static func reserveClientOrderIndices() async throws -> PerpsClientOrderIndices {
        try await clientOrderIndexAllocator.reserve(nowUnixMs: nowUnixMs())
    }

    /// Nothing reviewed is signed, so these never reach the disk.
    static func reviewClientOrderIndices() throws -> PerpsClientOrderIndices {
        let minimum = LighterConstants.shared.MinClientOrderIndex
        let maximum = LighterConstants.shared.MaxClientOrderIndex
        let candidate = max(nowUnixMs() % maximum, minimum)
        ephemeralClientOrderIndexLock.lock()
        defer { ephemeralClientOrderIndexLock.unlock() }
        let first = max(candidate, (lastEphemeralClientOrderIndex ?? minimum - 1) + 1)
        let lastReserved = first + PerpsClientOrderIndices.count - 1
        guard lastReserved < maximum else {
            throw PerpsTradingError.protocolFailure("client order index exhausted")
        }
        lastEphemeralClientOrderIndex = lastReserved
        return PerpsClientOrderIndices(first: first)
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
        receivedAtUnixMs: Int64,
        integrator: Components.Schemas.Integrator
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
        let minAdjustMarginQuote = try PerpsScaled.parse(minAdjustMarginUsd, decimals: quoteDecimals, rounding: .up)
        let minRemoveMarginBufferQuote = try PerpsScaled.parse(
            minRemoveMarginBufferUsd,
            decimals: quoteDecimals,
            rounding: .up
        )
        let scale = PerpsScale(
            priceDecimals: priceDecimals,
            baseDecimals: baseDecimals,
            quoteDecimals: quoteDecimals
        )
        let tick = try parseRequired(market.tick_size, decimals: priceDecimals, field: "tick_size", rounding: .up)
        let step = try parseRequired(market.step_size, decimals: baseDecimals, field: "step_size", rounding: .up)
        let minBase = try parseRequired(market.min_size_base, decimals: baseDecimals, field: "min_size_base", rounding: .up)
        let maxBase = try parseOptional(market.max_size_base, decimals: baseDecimals, rounding: .down)
        let minNotional = try parseOptional(market.min_size_quote, decimals: quoteDecimals, rounding: .up)
        let maxNotional = try parseOptional(market.max_size_quote, decimals: quoteDecimals, rounding: .down)
        let makerPpm = try ppm(market.maker_fee_pct, field: "maker_fee_pct")
        let takerPpm = try ppm(market.taker_fee_pct, field: "taker_fee_pct")
        guard let maintenanceMargin = market.maintenance_margin_fraction else {
            throw PerpsTradingError.validation("maintenance_margin_fraction is missing")
        }
        let maxInitial: Int32 = 10000
        let maintenance = Int32(maintenanceMargin)
        // `initial_margin_fraction` is the margin the venue opens a position at, not the
        // least it accepts — the limit is max_leverage, and reading the default as the
        // limit refuses every leverage above it. Derived through the same formula that
        // encodes a chosen leverage, so the two cannot disagree at the boundary.
        guard let venueFloor = market.max_leverage.flatMap({ $0 > 0 ? initialMarginBps(leverage: Double($0)) : nil })
            ?? market.initial_margin_fraction.map({ Int32($0) })
        else {
            throw PerpsTradingError.validation("market leverage limit is missing")
        }
        let minInitial = max(venueFloor, maintenance + 1)
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
            removeMarginBufferPpm: removeMarginBufferPpm,
            minRemoveMarginBufferQuote: minRemoveMarginBufferQuote,
            integrator: integratorFees(from: integrator),
            freshness: PerpsFreshness(receivedAtUnixMs: receivedAtUnixMs, sourceUpdatedAtUnixMs: nil)
        )
    }

    static func integratorFees(from integrator: Components.Schemas.Integrator) -> PerpsIntegratorFees {
        guard integrator.integrator_account_index != 0 else {
            return PerpsIntegratorFees.companion.NONE
        }
        // The planner receives the account and per-order rates from the backend.
        let rates = PerpsFeeRates(
            takerFeePpm: Int64(integrator.integrator_taker_fee),
            makerFeePpm: Int64(integrator.integrator_maker_fee)
        )
        return PerpsIntegratorFees(
            accountIndex: integrator.integrator_account_index,
            open: rates,
            close: rates,
            takeProfit: rates,
            stopLoss: rates
        )
    }

    static func context(
        scope: PerpsScope,
        marketId: Int64,
        screen: Components.Schemas.TradingScreen,
        rules: PerpsMarketRules,
        receivedAtUnixMs: Int64,
        restingOrders: [PerpsRestingOrder],
        ordersKnown: Bool,
        openInitialMarginBps: Int32? = nil
    ) throws -> PerpetualAccountSnapshot {
        let available = try parseOptional(
            screen.balance?.available_balance,
            decimals: rules.scale.quoteDecimals,
            rounding: .down
        )?.int64Value ?? 0
        let position = try positionState(screen.position?.value1, rules: rules, marketId: marketId)
        let openEnabled = PerpsBackendMapping.openEnabled(screen.flags)
        let marginSettings: PerpsMarginSettings
        if let position = screen.position?.value1, let leverage = position.leverage, leverage > 0 {
            let mode: Int32 = position.margin_mode == .cross
                ? 0
                : LighterConstants.shared.IsolatedMargin
            marginSettings = PerpsMarginSettings.Known(
                mode: mode,
                initialMarginBps: initialMarginBps(leverage: Double(leverage))
            )
        } else if let openInitialMarginBps,
                  screen.margin_mode?.value1 == .isolated,
                  let leverage = screen.leverage, leverage > 0,
                  initialMarginBps(leverage: Double(leverage)) == openInitialMarginBps
        {
            marginSettings = PerpsMarginSettings.Known(
                mode: LighterConstants.shared.IsolatedMargin,
                initialMarginBps: openInitialMarginBps
            )
        } else {
            marginSettings = PerpsMarginSettings.Unknown.shared
        }
        return PerpetualAccountSnapshot(
            scope: scope,
            marketId: marketId,
            freshness: PerpsFreshness(receivedAtUnixMs: receivedAtUnixMs, sourceUpdatedAtUnixMs: nil),
            completeness: ordersKnown
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
                limitPrice: parseOptional(order.price, decimals: rules.scale.priceDecimals, rounding: .nearest),
                triggerPrice: parseOptional(order.trigger_price, decimals: rules.scale.priceDecimals, rounding: .nearest),
                expiryUnixMs: order.expires_at.map { KotlinLong(value: Int64($0.timeIntervalSince1970 * 1000)) }
            )
        }
    }

    static func restingOrders(
        autoClose: Components.Schemas.PositionAutoClose?,
        positionSide: Components.Schemas.PositionSide?,
        rules: PerpsMarketRules
    ) throws -> [PerpsRestingOrder] {
        let closingSide: PerpsSide = positionSide == .short ? .long_ : .short_
        var orders = [PerpsRestingOrder]()
        let legs: [(Components.Schemas.PositionAutoCloseLeg?, Components.Schemas.OrderCategory)] = [
            (autoClose?.take_profit?.value1, .take_profit),
            (autoClose?.stop_loss?.value1, .stop_loss),
        ]
        for (leg, legCategory) in legs {
            guard let leg, let orderIndex = leg.order_index else { continue }
            try orders.append(PerpsRestingOrder(
                orderIndex: orderIndex,
                clientOrderIndex: leg.client_order_index.map { KotlinLong(value: $0) },
                side: closingSide,
                category: category(legCategory),
                orderType: orderType(leg.order_type, category: legCategory),
                status: status(nil),
                reduceOnly: true,
                positionTied: true,
                remainingBaseAmount: parseOptional(
                    leg.base_size,
                    decimals: rules.scale.baseDecimals,
                    rounding: .down
                )?.int64Value ?? 0,
                limitPrice: parseOptional(leg.price, decimals: rules.scale.priceDecimals, rounding: .nearest),
                triggerPrice: parseOptional(leg.trigger_price, decimals: rules.scale.priceDecimals, rounding: .nearest),
                expiryUnixMs: leg.valid_to.map { KotlinLong(value: $0 * 1000) }
            ))
        }
        return orders
    }

    struct SnapshotNeed {
        let side: PerpsSide?
        let coverageQuote: Int64
        let includeMark: Bool
    }

    static func snapshotNeed(intent: PerpsTradeIntent, context: PerpsMarketContext) -> SnapshotNeed {
        let mark = context.mark?.price ?? 0
        let quoteScale = pow10(context.rules.scale.quoteDecimals)
        func notional(_ base: Int64) -> Int64 {
            guard base > 0, mark > 0 else { return quoteScale }
            let value = Double(base) * Double(mark)
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

    static func effectiveTakerFeePpm(intent: PerpsTradeIntent, rules: PerpsMarketRules) -> Int64 {
        switch intent {
        case is PerpsTradeIntent.Open, is PerpsTradeIntent.Add:
            return rules.takerFeePpm + rules.integrator.open.takerFeePpm
        case is PerpsTradeIntent.Close:
            return rules.takerFeePpm + rules.integrator.close.takerFeePpm
        default:
            return rules.takerFeePpm
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
                price: parseRequired(level.price, decimals: rules.scale.priceDecimals, field: "book.price", rounding: .nearest),
                baseAmount: parseRequired(level.size, decimals: rules.scale.baseDecimals, field: "book.size", rounding: .down)
            )
        }
        let sourceUpdated = Int64(book.updated_at.timeIntervalSince1970 * 1000)
        logBookMarkDivergence(
            side: side,
            best: levels.first?.price,
            mark: mark,
            priceDecimals: rules.scale.priceDecimals,
            marketId: marketId,
            sourceUpdatedAtUnixMs: sourceUpdated,
            receivedAtUnixMs: receivedAtUnixMs
        )
        return PerpetualMarketSnapshot(
            snapshotId: UUID().uuidString,
            marketId: marketId,
            environment: environment,
            receivedAtUnixMs: receivedAtUnixMs,
            sourceUpdatedAtUnixMs: nil,
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

    static func logBookMarkDivergence(
        side: PerpsSide,
        best: Int64?,
        mark: PerpsMarkPrice?,
        priceDecimals: Int32,
        marketId: Int64,
        sourceUpdatedAtUnixMs: Int64,
        receivedAtUnixMs: Int64
    ) {
        guard let best, let mark else { return }
        let bestPrice = PerpsScaled.double(best, decimals: priceDecimals)
        let markPrice = PerpsScaled.double(mark.price, decimals: priceDecimals)
        guard bestPrice > 0, markPrice > 0 else { return }
        let divergencePpm = Int64((abs(bestPrice - markPrice) / markPrice * 1_000_000).rounded())
        guard divergencePpm > priceSlippagePpm else { return }
        Log.perps.w(
            """
            book disagrees with mark market=\(marketId) \
            side=\(side === PerpsSide.short_ ? "short" : "long") \
            best=\(bestPrice) mark=\(markPrice) divergence=\(divergencePpm)ppm \
            bookUpdatedAt=\(sourceUpdatedAtUnixMs) markObservedAt=\(mark.observedAtUnixMs) read=\(receivedAtUnixMs)
            """
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
        if let live, live > 0, let scaled = try? PerpsScaled.scale(live, decimals: decimals, rounding: .nearest), scaled > 0 {
            return PerpsMarkPrice(price: scaled, observedAtUnixMs: nowUnixMs)
        }
        guard let decimal else { return nil }
        return try PerpsMarkPrice(
            price: PerpsScaled.parse(decimal, decimals: decimals, rounding: .nearest),
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
        oldNotionalUsd: Double,
        liquidationBefore: Int64?
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
            liquidationPrice: liquidationChange(
                after: review.liquidationPrice,
                before: liquidationBefore,
                decimals: decimals.priceDecimals
            ),
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
        oldNotionalUsd: Double,
        liquidationBefore: Int64?
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
            liquidationPrice: liquidationChange(
                after: review.liquidationPrice,
                before: liquidationBefore,
                decimals: decimals.priceDecimals
            ),
            liquidationUnavailableReason: review.liquidationPrice == nil
                ? PerpsLiquidationReasonMapper.map(review.liquidationUnavailableReason)
                : nil,
            estimatedFeeUsd: PerpsScaled.double(review.estimatedFeeQuote, decimals: decimals.quoteDecimals)
        )
    }

    static func liquidationChange(
        after: KotlinLong?,
        before: Int64?,
        decimals: Int32
    ) -> PerpsValueChange? {
        guard let new = PerpsScaled.optionalDouble(after, decimals: decimals) else { return nil }
        return PerpsValueChange(
            old: before.map { PerpsScaled.double($0, decimals: decimals) } ?? new,
            new: new
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

    static func minimumOpenMarginUsd(
        _ open: PerpsTradeIntent.Open,
        rules: PerpsMarketRules,
        marketSnapshot: PerpetualMarketSnapshot?,
        nowUnixMs: Int64
    ) throws -> Double {
        let bounds = try perpsValue(PerpsTradeBounds().openBounds(
            intent: open,
            rules: rules,
            marketSnapshot: marketSnapshot,
            nowUnixMs: nowUnixMs
        ))
        return PerpsScaled.double(bounds.minMarginBudgetQuote, decimals: rules.scale.quoteDecimals)
    }

    static func marginChangeLimits(context: PerpsMarketContext) throws -> PerpsMarginChangeLimits {
        guard let mark = context.mark?.price else {
            throw PerpsTradingError.validation("mark price is missing")
        }
        let bounds = try perpsValue(PerpsTradeBounds().marginBounds(
            context: context.accountSnapshot,
            rules: context.rules,
            mark: mark
        ))
        if let unavailable = bounds.unavailable {
            throw PerpsTradingError.validation("margin bounds are unavailable: \(unavailable)")
        }
        let decimals = context.rules.scale.quoteDecimals
        let maxReduce = bounds.maxRemoveQuote
        return PerpsMarginChangeLimits(
            minUsd: PerpsScaled.double(context.rules.minAdjustMarginQuote, decimals: decimals),
            maxReduceUsd: PerpsScaled.double(maxReduce - maxReduce % pow10(max(decimals - 2, 0)), decimals: decimals)
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
    static func parseRequired(
        _ value: String?,
        decimals: Int32,
        field: String,
        rounding: PerpsScaled.Rounding
    ) throws -> Int64 {
        guard let value, !value.isEmpty else {
            throw PerpsTradingError.validation("\(field) is missing")
        }
        do {
            return try PerpsScaled.parse(value, decimals: decimals, rounding: rounding)
        } catch {
            throw PerpsTradingError.validation("\(field) is not a valid decimal")
        }
    }

    static func parseOptional(
        _ value: String?,
        decimals: Int32,
        rounding: PerpsScaled.Rounding
    ) throws -> KotlinLong? {
        guard let value, !value.isEmpty else { return nil }
        return try KotlinLong(value: PerpsScaled.parse(value, decimals: decimals, rounding: rounding))
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
        let base = try parseRequired(size, decimals: rules.scale.baseDecimals, field: "size", rounding: .down)
        guard base > 0 else { return PerpsPositionState.KnownFlat.shared }
        let side: PerpsSide = position.side == .short ? .short_ : .long_
        let entry = try parseRequired(
            position.avg_entry_price,
            decimals: rules.scale.priceDecimals,
            field: "avg_entry_price",
            rounding: .nearest
        )
        let margin = try parseRequired(
            position.allocated_margin,
            decimals: rules.scale.quoteDecimals,
            field: "allocated_margin",
            rounding: .down
        )
        return try PerpsPositionState.Present(
            positionId: positionId(marketId: marketId),
            side: side,
            baseAmount: base,
            entryPrice: entry,
            allocatedMarginQuote: margin,
            liquidationPrice: parseOptional(position.liquidation_price, decimals: rules.scale.priceDecimals, rounding: .nearest)
        )
    }

    static func remainingBase(_ order: Components.Schemas.Order, decimals: Int32) throws -> Int64 {
        let base = try parseOptional(order.base_size, decimals: decimals, rounding: .down)?.int64Value ?? 0
        let filled = try parseOptional(order.filled_base, decimals: decimals, rounding: .up)?.int64Value ?? 0
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
        case .none, .unknown: .open
        }
    }
}
