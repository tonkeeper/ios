import Foundation
import SwapAPI

public struct MultichainSwapRoute: Sendable, Hashable {
    public var routeId: String
    public var providerRouteId: String?
    public var aggregator: String
    public var protocolSlug: String?
    public var routeType: String
    public var sourceAmount: String?
    public var estimatedDestinationAmount: String
    public var minimumDestinationAmount: String
    public var estimatedTime: MultichainSwapTimeEstimate?
    public var totalSlippageBps: Int?
    public var valueDifferenceBps: Int?
    public var sourceUsdPrice: Double?
    public var destinationUsdPrice: Double?
    public var tags: [String]?
    public var warnings: [String]?
    public var fees: [MultichainSwapFee]?
    public var legs: [MultichainSwapLeg]
    public var dateExpire: Date
    public var riskLevel: String
    public var payloads: [MultichainSwapPreparedPayload]?

    public init(
        routeId: String,
        providerRouteId: String? = nil,
        aggregator: String,
        protocolSlug: String? = nil,
        routeType: String,
        sourceAmount: String? = nil,
        estimatedDestinationAmount: String,
        minimumDestinationAmount: String,
        estimatedTime: MultichainSwapTimeEstimate? = nil,
        totalSlippageBps: Int? = nil,
        valueDifferenceBps: Int? = nil,
        sourceUsdPrice: Double? = nil,
        destinationUsdPrice: Double? = nil,
        tags: [String]? = nil,
        warnings: [String]? = nil,
        fees: [MultichainSwapFee]? = nil,
        legs: [MultichainSwapLeg],
        dateExpire: Date,
        riskLevel: String,
        payloads: [MultichainSwapPreparedPayload]? = nil
    ) {
        self.routeId = routeId
        self.providerRouteId = providerRouteId
        self.aggregator = aggregator
        self.protocolSlug = protocolSlug
        self.routeType = routeType
        self.sourceAmount = sourceAmount
        self.estimatedDestinationAmount = estimatedDestinationAmount
        self.minimumDestinationAmount = minimumDestinationAmount
        self.estimatedTime = estimatedTime
        self.totalSlippageBps = totalSlippageBps
        self.valueDifferenceBps = valueDifferenceBps
        self.sourceUsdPrice = sourceUsdPrice
        self.destinationUsdPrice = destinationUsdPrice
        self.tags = tags
        self.warnings = warnings
        self.fees = fees
        self.legs = legs
        self.dateExpire = dateExpire
        self.riskLevel = riskLevel
        self.payloads = payloads
    }
}

extension MultichainSwapRoute {
    init(api: SwapAPI.Components.Schemas.CrossSwapRoute) {
        self.init(
            routeId: api.route_id,
            providerRouteId: api.provider_route_id,
            aggregator: api.aggregator.rawValue,
            protocolSlug: api._protocol,
            routeType: api.route_type.rawValue,
            sourceAmount: api.source_amount,
            estimatedDestinationAmount: api.estimated_destination_amount,
            minimumDestinationAmount: api.minimum_destination_amount,
            estimatedTime: api.estimated_time.map { MultichainSwapTimeEstimate(api: $0) },
            totalSlippageBps: api.total_slippage_bps,
            valueDifferenceBps: api.value_difference_bps,
            sourceUsdPrice: api.source_usd_price,
            destinationUsdPrice: api.destination_usd_price,
            tags: api.tags?.map(\.rawValue),
            warnings: api.warnings,
            fees: api.fees?.map { MultichainSwapFee(api: $0) },
            legs: api.legs.map { MultichainSwapLeg(api: $0) },
            dateExpire: api.date_expire,
            riskLevel: api.risk_level.rawValue,
            payloads: api.payloads?.map { MultichainSwapPreparedPayload(api: $0) }
        )
    }
}
