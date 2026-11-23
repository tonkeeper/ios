import Foundation
import PerpsModels
import TKPerpsAPI

struct PerpsSignedMarketRefusal: Error, Equatable {
    let error: PerpsTradingError
    let reason: String
}

enum PerpsSignedMarketCheck {
    static func signedMarket(
        marketId: Int64,
        market: Components.Schemas.Market,
        config: PerpsSecurityConfig?
    ) throws -> PerpsSignedMarket {
        guard PerpsSignedMarket.signableIds.contains(marketId) else {
            throw PerpsSignedMarketRefusal(
                error: .tradingUnavailable,
                reason: "market \(marketId) is out of the signable range"
            )
        }
        guard let config else {
            throw PerpsTradingError.tradingUnavailable
        }
        guard let signed = config.markets[marketId] else {
            throw PerpsSignedMarketRefusal(
                error: .tradingUnavailable,
                reason: "market \(marketId) is not in the signed perps config"
            )
        }
        guard signed.maxLeverage >= 1 else {
            throw PerpsSignedMarketRefusal(
                error: .tradingUnavailable,
                reason: "the signed perps config allows no leverage on market \(marketId)"
            )
        }
        try requireSame(marketId, "market_index", served: market.market_index.map(Int64.init), signed: marketId)
        guard market.symbol == signed.symbol else {
            throw mismatch(marketId, "symbol", served: market.symbol, signed: signed.symbol)
        }
        try requireSame(marketId, "price_decimals", served: market.price_decimals.map(Int64.init), signed: Int64(signed.priceDecimals))
        try requireSame(marketId, "size_decimals", served: market.size_decimals.map(Int64.init), signed: Int64(signed.sizeDecimals))
        try requireSameAmount(marketId, "min_size_base", served: market.min_size_base, signed: signed.minBaseAmount)
        try requireSameAmount(marketId, "min_size_quote", served: market.min_size_quote, signed: signed.minQuoteAmount)
        try requireSame(marketId, "max_leverage", served: market.max_leverage.map(Int64.init), signed: Int64(signed.maxLeverage))
        return signed
    }

    private static func requireSame(_ marketId: Int64, _ field: String, served: Int64?, signed: Int64) throws {
        guard served == signed else {
            throw mismatch(marketId, field, served: served.map(String.init), signed: String(signed))
        }
    }

    private static func requireSameAmount(_ marketId: Int64, _ field: String, served: String?, signed: String) throws {
        guard let served, PerpsSecurityConfigReader.isPlainAmount(served),
              let servedAmount = decimal(served), let signedAmount = decimal(signed), servedAmount == signedAmount
        else {
            throw mismatch(marketId, field, served: served, signed: signed)
        }
    }

    private static func decimal(_ value: String) -> Decimal? {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func mismatch(_ marketId: Int64, _ field: String, served: String?, signed: String) -> PerpsSignedMarketRefusal {
        PerpsSignedMarketRefusal(
            error: .validation("market \(marketId) \(field) \(served ?? "nil") differs from the signed perps config's \(signed)"),
            reason: "\(field) differs"
        )
    }
}
