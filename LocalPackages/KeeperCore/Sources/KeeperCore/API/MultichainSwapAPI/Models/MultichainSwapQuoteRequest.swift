import SwapAPI

public struct MultichainSwapQuoteRequest: Sendable, Hashable {
    public var sourceAsset: String
    public var sourceAmount: String
    public var destinationAsset: String
    public var senderAddress: String
    public var recipientAddress: String
    public var slippageBps: Int?
    public var exactType: String?
    public var aggregators: [String]?
    public var protocols: [String]?
    public var returnDepositAddress: Bool?
    public var includePayload: Bool?
    /// True when `sourceAmount` is the wallet's whole spendable balance. SwapsXYZ then builds
    /// a transfer that still fits once its own fee is included.
    public var isMax: Bool?

    public init(
        sourceAsset: String,
        sourceAmount: String,
        destinationAsset: String,
        senderAddress: String,
        recipientAddress: String,
        slippageBps: Int? = nil,
        exactType: String? = nil,
        aggregators: [String]? = nil,
        protocols: [String]? = nil,
        returnDepositAddress: Bool? = nil,
        includePayload: Bool? = nil,
        isMax: Bool? = nil
    ) {
        self.sourceAsset = sourceAsset
        self.sourceAmount = sourceAmount
        self.destinationAsset = destinationAsset
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.slippageBps = slippageBps
        self.exactType = exactType
        self.aggregators = aggregators
        self.protocols = protocols
        self.returnDepositAddress = returnDepositAddress
        self.includePayload = includePayload
        self.isMax = isMax
    }
}

extension MultichainSwapQuoteRequest {
    func swapAPIRequestBody() -> SwapAPI.Components.RequestBodies.CrossSwapQuote {
        let aggregatorsAPI = aggregators?.compactMap { SwapAPI.Components.Schemas.CrossSwapAggregator(rawValue: $0) }
        let exactTypeAPI = exactType.flatMap { SwapAPI.Components.Schemas.CrossSwapExactType(rawValue: $0) }
        return .json(
            .init(
                source_asset: sourceAsset,
                source_amount: sourceAmount,
                destination_asset: destinationAsset,
                sender_address: senderAddress,
                recipient_address: recipientAddress,
                return_deposit_address: returnDepositAddress,
                is_max: isMax,
                slippage_bps: slippageBps,
                exact_type: exactTypeAPI,
                aggregators: aggregatorsAPI,
                protocols: protocols,
                include_payload: includePayload
            )
        )
    }
}
