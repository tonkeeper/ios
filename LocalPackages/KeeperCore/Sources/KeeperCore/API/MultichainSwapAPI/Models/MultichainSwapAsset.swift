import SwapAPI

public struct MultichainSwapAsset: Sendable, Hashable {
    public var assetId: String
    public var symbol: String
    public var name: String
    public var decimals: Int
    public var image: String?
    public var chainFamily: String
    public var stablecoin: Bool
    public var supportedAggregators: [String]
    public var allowedCounterparts: [String]?
    public var usdPrice: Double?

    public init(
        assetId: String,
        symbol: String,
        name: String,
        decimals: Int,
        image: String? = nil,
        chainFamily: String,
        stablecoin: Bool = false,
        supportedAggregators: [String],
        allowedCounterparts: [String]? = nil,
        usdPrice: Double? = nil
    ) {
        self.assetId = assetId
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.image = image
        self.chainFamily = chainFamily
        self.stablecoin = stablecoin
        self.supportedAggregators = supportedAggregators
        self.allowedCounterparts = allowedCounterparts
        self.usdPrice = usdPrice
    }
}

extension MultichainSwapAsset {
    init(api: SwapAPI.Components.Schemas.CrossSwapAsset) {
        self.init(
            assetId: api.asset_id,
            symbol: api.symbol,
            name: api.name,
            decimals: api.decimals,
            image: api.image,
            chainFamily: api.chain_family.rawValue,
            stablecoin: api.stablecoin ?? false,
            supportedAggregators: api.supported_aggregators.map(\.rawValue),
            allowedCounterparts: api.allowed_counterparts,
            usdPrice: api.usd_price
        )
    }
}
