import Foundation

public struct PerpsAssetMarketSnapshot: Equatable {
    public let marketId: Int64
    public let symbol: String
    public let displayName: String
    public let status: String
    public let maxLeverage: Double
    public let priceDecimals: Int
    public let sizeDecimals: Int
    public let price: Double
    public let priceChangePercent: Double
    public let priceChangeAmount: Double
    public let volume24h: Double
    public let openInterest: Double
    public let fundingRatePercent: Double?
    public let about: String?
    public let openEnabled: Bool
    public let iconURL: URL?

    public var isTradingEnabled: Bool {
        openEnabled
    }

    public var hasPrice: Bool {
        price > 0
    }

    public init(
        marketId: Int64,
        symbol: String,
        displayName: String,
        status: String,
        maxLeverage: Double,
        priceDecimals: Int,
        sizeDecimals: Int,
        price: Double,
        priceChangePercent: Double,
        priceChangeAmount: Double,
        volume24h: Double,
        openInterest: Double,
        fundingRatePercent: Double?,
        about: String?,
        openEnabled: Bool,
        iconURL: URL? = nil
    ) {
        self.marketId = marketId
        self.symbol = symbol
        self.displayName = displayName
        self.status = status
        self.maxLeverage = maxLeverage
        self.priceDecimals = priceDecimals
        self.sizeDecimals = sizeDecimals
        self.price = price
        self.priceChangePercent = priceChangePercent
        self.priceChangeAmount = priceChangeAmount
        self.volume24h = volume24h
        self.openInterest = openInterest
        self.fundingRatePercent = fundingRatePercent
        self.about = about
        self.openEnabled = openEnabled
        self.iconURL = iconURL
    }
}

extension PerpsAssetMarketSnapshot {
    init(details: PerpsMarketDetails) {
        let market = details.metadata
        let price = market.displayPrice
        self.init(
            marketId: market.marketId,
            symbol: market.symbol,
            displayName: details.name.nilIfEmpty ?? market.symbol,
            status: market.status,
            maxLeverage: market.maxLeverage,
            priceDecimals: market.priceDecimals,
            sizeDecimals: market.sizeDecimals,
            price: price,
            priceChangePercent: market.priceChangePercent,
            priceChangeAmount: PerpsMarketMath.changeAmount(price: price, changePercent: market.priceChangePercent),
            volume24h: market.volume24h,
            openInterest: market.openInterest,
            fundingRatePercent: market.fundingRatePercent,
            about: details.about,
            openEnabled: market.status.lowercased() == "active",
            iconURL: details.iconURL
        )
    }

    public func overlayingLivePrice(_ livePrice: Double?) -> PerpsAssetMarketSnapshot {
        guard let livePrice, livePrice > 0, livePrice != price else { return self }
        let livePercent = PerpsMarketMath.changePercent(
            livePrice: livePrice,
            snapshotPrice: price,
            snapshotChangePercent: priceChangePercent
        )
        return PerpsAssetMarketSnapshot(
            marketId: marketId,
            symbol: symbol,
            displayName: displayName,
            status: status,
            maxLeverage: maxLeverage,
            priceDecimals: priceDecimals,
            sizeDecimals: sizeDecimals,
            price: livePrice,
            priceChangePercent: livePercent,
            priceChangeAmount: PerpsMarketMath.changeAmount(price: livePrice, changePercent: livePercent),
            volume24h: volume24h,
            openInterest: openInterest,
            fundingRatePercent: fundingRatePercent,
            about: about,
            openEnabled: openEnabled,
            iconURL: iconURL
        )
    }
}

public enum PerpsMarketMath {
    public static func double(_ string: String?) -> Double {
        optionalDouble(string) ?? 0
    }

    public static func optionalDouble(_ string: String?) -> Double? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let decimal = Decimal(string: trimmed) else { return nil }
        return NSDecimalNumber(decimal: decimal).doubleValue
    }

    public static func changeAmount(price: Double, changePercent: Double) -> Double {
        let factor = 1 + changePercent / 100
        guard factor > 0.01 else { return 0 }
        return price - price / factor
    }

    /// 24h change re-derived for a live price: the snapshot's price and percent pin the
    /// 24h-ago baseline, and the live price is compared against that same baseline. The
    /// baseline drifts as the 24-hour window slides, which the slow snapshot re-anchor
    /// corrects.
    public static func changePercent(
        livePrice: Double,
        snapshotPrice: Double,
        snapshotChangePercent: Double
    ) -> Double {
        let factor = 1 + snapshotChangePercent / 100
        guard factor > 0.01, snapshotPrice > 0, livePrice > 0 else { return snapshotChangePercent }
        let baseline = snapshotPrice / factor
        return (livePrice / baseline - 1) * 100
    }
}
