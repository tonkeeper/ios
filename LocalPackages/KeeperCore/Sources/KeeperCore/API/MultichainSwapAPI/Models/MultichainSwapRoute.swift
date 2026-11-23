import Foundation
import SwapAPI

public struct MultichainSwapRoute: Sendable, Hashable {
    public var routeId: String
    public var providerRouteId: String?
    public var aggregator: String
    public var protocolSlug: String?
    public var routeType: String
    public var sourceAmount: String?
    public var maximumSourceAmount: String?
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
    /// The API the route was quoted on: it is prepared there whatever the flag that picked it says now.
    public var apiVersion: MultichainSwapAPIVersion

    public init(
        routeId: String,
        providerRouteId: String? = nil,
        aggregator: String,
        protocolSlug: String? = nil,
        routeType: String,
        sourceAmount: String? = nil,
        maximumSourceAmount: String? = nil,
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
        payloads: [MultichainSwapPreparedPayload]? = nil,
        apiVersion: MultichainSwapAPIVersion = .v2
    ) {
        self.routeId = routeId
        self.providerRouteId = providerRouteId
        self.aggregator = aggregator
        self.protocolSlug = protocolSlug
        self.routeType = routeType
        self.sourceAmount = sourceAmount
        self.maximumSourceAmount = maximumSourceAmount
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
        self.apiVersion = apiVersion
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
            maximumSourceAmount: api.maximum_source_amount,
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

    /// A `/v3` route is a `/v2` one without payloads: `prepareCrossSwapRouteV3` builds its operation.
    init(api: SwapAPI.Components.Schemas.CrossSwapQuotedRoute) {
        self.init(
            api: SwapAPI.Components.Schemas.CrossSwapRoute(
                route_id: api.route_id,
                provider_route_id: api.provider_route_id,
                aggregator: api.aggregator,
                _protocol: api._protocol,
                route_type: api.route_type,
                source_amount: api.source_amount,
                maximum_source_amount: api.maximum_source_amount,
                estimated_destination_amount: api.estimated_destination_amount,
                minimum_destination_amount: api.minimum_destination_amount,
                estimated_time: api.estimated_time,
                total_slippage_bps: api.total_slippage_bps,
                value_difference_bps: api.value_difference_bps,
                price_impact_bps: api.price_impact_bps,
                source_usd_price: api.source_usd_price,
                destination_usd_price: api.destination_usd_price,
                tags: api.tags,
                warnings: api.warnings,
                fees: api.fees,
                legs: api.legs,
                date_expire: api.date_expire,
                risk_level: api.risk_level
            )
        )
        apiVersion = .v3
    }
}
