import SwapAPI

public struct MultichainSwapLeg: Sendable, Hashable {
    public var legIndex: Int
    public var type: String
    public var chainId: String
    public var chainFamily: String
    public var fromAsset: String?
    public var toAsset: String?
    public var fromAmount: String?
    public var estimatedToAmount: String?
    public var protocolSlug: String?

    public init(
        legIndex: Int,
        type: String,
        chainId: String,
        chainFamily: String,
        fromAsset: String? = nil,
        toAsset: String? = nil,
        fromAmount: String? = nil,
        estimatedToAmount: String? = nil,
        protocolSlug: String? = nil
    ) {
        self.legIndex = legIndex
        self.type = type
        self.chainId = chainId
        self.chainFamily = chainFamily
        self.fromAsset = fromAsset
        self.toAsset = toAsset
        self.fromAmount = fromAmount
        self.estimatedToAmount = estimatedToAmount
        self.protocolSlug = protocolSlug
    }
}

extension MultichainSwapLeg {
    init(api: SwapAPI.Components.Schemas.CrossSwapLeg) {
        self.init(
            legIndex: api.leg_index,
            type: api._type.rawValue,
            chainId: api.chain_id,
            chainFamily: api.chain_family.rawValue,
            fromAsset: api.from_asset,
            toAsset: api.to_asset,
            fromAmount: api.from_amount,
            estimatedToAmount: api.estimated_to_amount,
            protocolSlug: api._protocol
        )
    }
}
