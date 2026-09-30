import Foundation
import TKTradingAPI

struct PerpsMarketDetails: Equatable, Sendable {
    let metadata: PerpsMarketMetadata
    let name: String
    let iconURL: URL?
    let about: String?
}

extension PerpsMarketDetails {
    init?(response: Components.Schemas.AssetDetailsResponse) {
        guard let perps = response.asset.perps,
              let metadata = PerpsMarketMetadata(perps: perps)
        else {
            return nil
        }
        let about = response.sections.about
        self.init(
            metadata: metadata,
            name: response.asset.name,
            iconURL: response.asset.image_url.nilIfEmpty.flatMap { URL(string: $0) },
            about: about.enabled
                ? about.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                : nil
        )
    }
}

extension PerpsMarketMetadata {
    init?(perps value: Components.Schemas.PerpMarket) {
        guard let marketId = Int64(exactly: value.market_index),
              let symbol = value.symbol.nilIfEmpty,
              let minBaseSize = PerpsMarketMath.optionalDouble(value.min_size_base),
              value.price_decimals >= 0,
              value.size_decimals >= 0,
              value.max_leverage > 0,
              minBaseSize > 0
        else {
            return nil
        }
        self.init(
            marketId: marketId,
            symbol: symbol,
            ticker: PerpsMarketTicker.make(base: value.base_asset.nilIfEmpty ?? symbol, quote: value.quote_asset),
            status: value.status,
            markPrice: PerpsMarketMath.optionalDouble(value.mark_price),
            lastTradePrice: PerpsMarketMath.optionalDouble(value.last_price),
            priceChangePercent: PerpsMarketMath.optionalDouble(value.price_change_24h) ?? 0,
            volume24h: PerpsMarketMath.optionalDouble(value.volume_24h_usd) ?? 0,
            openInterest: PerpsMarketMath.optionalDouble(value.open_interest_usd) ?? 0,
            maxLeverage: Double(value.max_leverage),
            fundingRatePercent: PerpsMarketMath.optionalDouble(value.funding_rate_hourly).map { $0 * 100 },
            priceDecimals: value.price_decimals,
            sizeDecimals: value.size_decimals,
            minBaseSize: minBaseSize
        )
    }
}

enum PerpsMarketTicker {
    static func make(base: String, quote: String?) -> String {
        let quoteAsset = (quote?.nilIfEmpty ?? "USD").replacingOccurrences(of: "USDC", with: "USD")
        return "\(base)/\(quoteAsset)"
    }
}
