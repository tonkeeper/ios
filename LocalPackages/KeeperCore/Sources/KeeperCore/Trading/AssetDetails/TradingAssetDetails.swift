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
}

extension TradingAssetDetails {
    init(
        response: Components.Schemas.AssetDetailsResponse,
        currency: Currency
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
            infoSource: TradingAssetInfoSource(api: response.info_source)
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
