import SwapAPI

public struct MultichainSwapFee: Sendable, Hashable {
    public var type: String
    public var asset: String
    public var chainId: String?
    public var amount: String
    public var amountUsd: String?

    public init(type: String, asset: String, chainId: String? = nil, amount: String, amountUsd: String? = nil) {
        self.type = type
        self.asset = asset
        self.chainId = chainId
        self.amount = amount
        self.amountUsd = amountUsd
    }
}

extension MultichainSwapFee {
    init(api: SwapAPI.Components.Schemas.CrossSwapFee) {
        self.init(
            type: api._type,
            asset: api.asset,
            chainId: api.chain_id,
            amount: api.amount,
            amountUsd: api.amount_usd
        )
    }
}
