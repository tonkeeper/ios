@preconcurrency import BigInt
import Foundation
import TKLocalize
import TKTradingAPI

public struct TradingAssetDetails: Equatable, Sendable {
    public var id: String
    public var assetInfo: TradingAssetInfo
    public var capabilities: Set<TradingAssetCapability>
    public var aboutParagraph: String
    public var overview: [TradingAssetMetric]
    public var tradingActivity: TradingAssetTradingActivity?
    public var links: [TradingAssetLink]
    public var primaryActionTitle: String
    public var infoSource: TradingAssetInfoSource
    public var perpMarket: TradingAssetPerpMarket?
    public var swapAggregators: Set<MultichainSwapAggregator>?
}

public struct TradingAssetPerpMarket: Equatable, Sendable {
    public var marketId: Int64
    public var maxLeverage: Int?

    public init(marketId: Int64, maxLeverage: Int?) {
        self.marketId = marketId
        self.maxLeverage = maxLeverage
    }
}

extension TradingAssetDetails {
    init(
        response: Components.Schemas.AssetDetailsResponse,
        currency: Currency,
        signedPerpSymbols: [Int64: String]? = nil
    ) {
        self.init(
            id: response.asset.id,
            assetInfo: TradingAssetInfo(
                assetId: response.asset.id,
                category: response.asset.asset_type.asCategory,
                address: response.asset.id.tradingAssetAddress,
                symbol: response.asset.symbol,
                decimals: response.asset.decimals,
                title: response.asset.name,
                imageURL: URL(
                    string: response.asset.image_url
                ),
                price: nil,
                changePercent: nil,
                changeAmount: nil,
                earnAPY: nil,
                verification: TradingVerification(api: response.asset.verification)
            ),
            capabilities: Set(
                (response.capabilities?.capabilities ?? []).compactMap(TradingAssetCapability.init(api:))
            ),
            aboutParagraph: response.sections.about.text
                ?? response.sections.about.note
                ?? TKLocales.Trade.AssetDetails.aboutFallback(response.asset.name),
            overview: {
                guard response.sections.overview.enabled else {
                    return []
                }

                var metrics = [TradingAssetMetric]()

                if let marketCap = response.sections.overview.market_cap {
                    metrics.append(
                        .marketCap(
                            value: "\(currency.symbol)\(marketCap)",
                            secondaryValue: nil,
                            secondaryValueIsPositive: true
                        )
                    )
                }
                if let totalSupply = response.sections.overview.total_supply {
                    metrics.append(
                        .totalSupply(value: totalSupply)
                    )
                }
                if let circulatingSupply = response.sections.overview.circulating_supply {
                    metrics.append(
                        .circulatingSupply(value: circulatingSupply)
                    )
                }
                return metrics
            }(),
            tradingActivity: response.sections.trading_activity.enabled ? TradingAssetTradingActivity(
                volumeText: response.sections.trading_activity.volume_24h ?? TKLocales.Trade.AssetDetails.Common.notAvailable,
                volumeChangeText: response.sections.trading_activity.volume_change_24h,
                buyText: response.sections.trading_activity.buy_24h ?? TKLocales.Trade.AssetDetails.Common.notAvailable,
                sellText: response.sections.trading_activity.sell_24h ?? TKLocales.Trade.AssetDetails.Common.notAvailable,
                buyFraction: {
                    let buyValue = response.sections.trading_activity.buy_24h
                        .flatMap(NSDecimalNumber.init(string:))?.decimalValue ?? 0
                    let sellValue = response.sections.trading_activity.sell_24h
                        .flatMap(NSDecimalNumber.init(string:))?.decimalValue ?? 0
                    let totalValue = buyValue + sellValue
                    return totalValue > 0 ? NSDecimalNumber(decimal: buyValue / totalValue).doubleValue : 0.5
                }()
            ) : nil,
            links: response.sections.links.enabled ?
                (response.sections.links.items ?? [])
                .map(TradingAssetLink.init(response:)) : [],
            primaryActionTitle: TKLocales.BuySellList.buy,
            infoSource: TradingAssetInfoSource(api: response.info_source),
            perpMarket: response.asset.perp_markets?
                .lazy
                .compactMap { TradingAssetPerpMarket(link: $0, signedSymbols: signedPerpSymbols) }
                .first,
            swapAggregators: response.capabilities?.details?.swap?.aggregators.map {
                Set($0.compactMap(MultichainSwapAggregator.init(rawValue:)))
            }
        )
    }
}

extension TradingAssetInfoSource {
    init(api: Components.Schemas.AssetInfoSource) {
        self.init(
            displayedName: api.displayed_name,
            url: URL(string: api.url)
        )
    }
}

private extension TradingAssetPerpMarket {
    init?(link: Components.Schemas.PerpMarketLink, signedSymbols: [Int64: String]?) {
        guard let marketId = PerpsMarketAssetID.marketId(assetId: link.id),
              signedSymbols.map({ Int64(link.market_index) == marketId && $0[marketId] == link.symbol }) ?? true
        else {
            return nil
        }
        self.init(marketId: marketId, maxLeverage: link.max_leverage)
    }
}

private extension TradingAssetCapability {
    init?(api: Components.Schemas.AssetCapability) {
        switch api {
        case .onramp:
            self = .onramp
        case .offramp:
            self = .offramp
        case .swap:
            self = .swap
        case .p2p:
            self = .p2p
        case .unknown:
            return nil
        }
    }
}

private extension String {
    var tradingAssetAddress: String {
        split(separator: "/", omittingEmptySubsequences: true)
            .last
            .map(String.init) ?? self
    }
}
