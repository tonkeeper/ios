@preconcurrency import BigInt
import SwapAPI

/// The side of the swap a quote fixes, in base units: the amount sold (`exact_input`) or the amount
/// received (`exact_output`). The route then reports the other side.
@frozen public enum MultichainSwapQuoteAmount: Sendable, Hashable {
    case source(BigUInt)
    case destination(BigUInt)
}

public struct MultichainSwapQuoteRequest: Sendable, Hashable {
    public var sourceAsset: String
    public var destinationAsset: String
    public var amount: MultichainSwapQuoteAmount
    public var senderAddress: String
    public var recipientAddress: String
    public var slippageBps: Int?
    public var aggregators: [String]?
    public var protocols: [String]?
    public var returnDepositAddress: Bool?
    public var includePayload: Bool?
    /// True when the source amount is the wallet's whole spendable balance. SwapsXYZ then builds
    /// a transfer that still fits once its own fee is included.
    public var isMax: Bool?

    public init(
        sourceAsset: String,
        destinationAsset: String,
        amount: MultichainSwapQuoteAmount,
        senderAddress: String,
        recipientAddress: String,
        slippageBps: Int? = nil,
        aggregators: [String]? = nil,
        protocols: [String]? = nil,
        returnDepositAddress: Bool? = nil,
        includePayload: Bool? = nil,
        isMax: Bool? = nil
    ) {
        self.sourceAsset = sourceAsset
        self.destinationAsset = destinationAsset
        self.amount = amount
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.slippageBps = slippageBps
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
        let (sourceAmount, destinationAmount, exactType): (String?, String?, SwapAPI.Components.Schemas.CrossSwapExactType) =
            switch amount {
            case let .source(value):
                (value.description, nil, .exact_input)
            case let .destination(value):
                (nil, value.description, .exact_output)
            }
        return .json(
            .init(
                source_asset: sourceAsset,
                source_amount: sourceAmount,
                destination_asset: destinationAsset,
                destination_amount: destinationAmount,
                sender_address: senderAddress,
                recipient_address: recipientAddress,
                return_deposit_address: returnDepositAddress,
                is_max: isMax,
                slippage_bps: slippageBps,
                exact_type: exactType,
                aggregators: aggregatorsAPI,
                protocols: protocols,
                include_payload: includePayload
            )
        )
    }

    /// What `/v2` is asked, without `include_payload`: a `/v3` route carries no payloads.
    func swapAPIRequestBodyV3() -> SwapAPI.Components.RequestBodies.CrossSwapQuoteV3 {
        switch swapAPIRequestBody() {
        case let .json(v2):
            .json(
                .init(
                    source_asset: v2.source_asset,
                    source_amount: v2.source_amount,
                    destination_asset: v2.destination_asset,
                    destination_amount: v2.destination_amount,
                    sender_address: v2.sender_address,
                    recipient_address: v2.recipient_address,
                    return_deposit_address: v2.return_deposit_address,
                    use_multi_aggregator: v2.use_multi_aggregator,
                    is_max: v2.is_max,
                    slippage_bps: v2.slippage_bps,
                    exact_type: v2.exact_type,
                    aggregators: v2.aggregators,
                    protocols: v2.protocols
                )
            )
        }
    }
}
