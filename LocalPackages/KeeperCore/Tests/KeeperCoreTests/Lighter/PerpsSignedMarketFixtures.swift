import ChainKit
@testable import KeeperCore
import TKPerpsAPI

extension PerpsSignedMarket {
    static func matching(
        _ market: Components.Schemas.Market,
        quoteDecimals: Int32? = nil,
        maxLeverage: Int32? = nil
    ) -> PerpsSignedMarket {
        let priceDecimals = Int32(market.price_decimals ?? 0)
        let sizeDecimals = Int32(market.size_decimals ?? 0)
        let servedLeverage = market.max_leverage.map(Int32.init)
            ?? market.initial_margin_fraction.map { Int32(10000 / $0) }
            ?? 1
        return PerpsSignedMarket(
            marketId: Int64(market.market_index ?? 0),
            symbol: market.symbol ?? "",
            priceDecimals: priceDecimals,
            sizeDecimals: sizeDecimals,
            quoteDecimals: quoteDecimals ?? priceDecimals + sizeDecimals,
            minBaseAmount: market.min_size_base ?? "0",
            minQuoteAmount: market.min_size_quote ?? "0",
            maxLeverage: maxLeverage ?? servedLeverage
        )
    }
}

extension PerpsSecurityConfig {
    static func listing(_ markets: PerpsSignedMarket...) -> PerpsSecurityConfig {
        PerpsSecurityConfig(
            version: 2,
            hermesDelegate: "0x24b576bc271823bf9c24be627b4363b9b00191e9",
            hermesDelegateChains: ["eth"],
            changePubKeyContract: "0x183ef7195d443a3da7ec1d7003baca1ff490757d",
            markets: Dictionary(uniqueKeysWithValues: markets.map { ($0.marketId, $0) })
        )
    }
}

extension PerpsPlannerMapping {
    static func rulesSignedAsServed(
        market: Components.Schemas.Market,
        environment: String,
        receivedAtUnixMs: Int64,
        integrator: Components.Schemas.Integrator
    ) throws -> PerpsMarketRules {
        try rules(
            market: market,
            signed: .matching(market),
            environment: environment,
            receivedAtUnixMs: receivedAtUnixMs,
            integrator: integrator
        )
    }
}
