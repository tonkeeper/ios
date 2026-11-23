@preconcurrency import BigInt
import Foundation

public struct MultichainSwapExecutionPlan: Sendable {
    /// What a plan signs.
    enum Signs: Sendable {
        /// The payloads `/v2` prepared, each normalized for the provider's pipeline.
        case payloads(MultichainSwapRoutePayloads)
        /// The operation `/v3` built for the route, signed as it stands.
        case operation(MultichainSwapOperation)
    }

    public var routeId: String
    /// The aggregator that issued the route: `providerRouteId` is only meaningful against it, and
    /// the signing pipeline is picked from it, so both stay in step by construction.
    public var aggregator: MultichainSwapAggregator
    public var providerRouteId: String?
    var signs: Signs
    public var networkFees: [MultichainTransactionEmulationResult]
    public var requiresApproval: Bool
    /// Battery first, the source chain's own coin last; empty until the fee methods are resolved.
    public var feeOptions: [MultichainSwapFeeOption]
    var payloadFees: MultichainSwapPayloadFees
    /// The main payload in the shape a battery method sends it, so a chosen method needs no re-derivation.
    var batteryPayload: MultichainSwapBatteryPayload?
    /// What the route takes out of the source asset, in its base units, for a fee paid in that asset.
    var spentSourceAmount: BigUInt?
    var sourceAmount: String?
    /// What the chain's coin falls short of where a relayed method keeps a route `/v3` prepared: the fee
    /// and the coin the payloads send beside the amount sold, of which the native option names only the
    /// fee. `nil` while the coin covers the swap, and for a route `/v2` prepared.
    public var nativeFeeShortage: MultichainNativeFeeShortage?

    public var provider: MultichainSwapProvider {
        aggregator.provider
    }

    /// The route as the operation `/v3` built receives: the backend may price it again between the
    /// quote and the build. `nil` for a route `/v2` prepared.
    public var preparedRoute: MultichainSwapRoute? {
        guard case let .operation(operation) = signs else {
            return nil
        }
        return operation.route
    }

    /// When the operation `/v3` built for the route stops being signed, which can come before the route
    /// expires. `nil` for a route `/v2` prepared.
    public var expiresAt: Date? {
        guard case let .operation(operation) = signs else {
            return nil
        }
        return operation.expiresAt
    }

    init(
        routeId: String,
        aggregator: MultichainSwapAggregator,
        providerRouteId: String? = nil,
        payloads: MultichainSwapRoutePayloads,
        networkFees: [MultichainTransactionEmulationResult],
        requiresApproval: Bool = false,
        feeOptions: [MultichainSwapFeeOption] = [],
        payloadFees: MultichainSwapPayloadFees,
        batteryPayload: MultichainSwapBatteryPayload? = nil,
        spentSourceAmount: BigUInt? = nil,
        sourceAmount: String? = nil
    ) {
        self.init(
            routeId: routeId,
            aggregator: aggregator,
            providerRouteId: providerRouteId,
            signs: .payloads(payloads),
            networkFees: networkFees,
            requiresApproval: requiresApproval,
            feeOptions: feeOptions,
            payloadFees: payloadFees,
            batteryPayload: batteryPayload,
            spentSourceAmount: spentSourceAmount,
            sourceAmount: sourceAmount
        )
    }

    init(
        routeId: String,
        aggregator: MultichainSwapAggregator,
        providerRouteId: String?,
        signs: Signs,
        networkFees: [MultichainTransactionEmulationResult],
        requiresApproval: Bool = false,
        feeOptions: [MultichainSwapFeeOption],
        payloadFees: MultichainSwapPayloadFees = [:],
        batteryPayload: MultichainSwapBatteryPayload? = nil,
        spentSourceAmount: BigUInt? = nil,
        sourceAmount: String?,
        nativeFeeShortage: MultichainNativeFeeShortage? = nil
    ) {
        self.routeId = routeId
        self.aggregator = aggregator
        self.providerRouteId = providerRouteId
        self.signs = signs
        self.networkFees = networkFees
        self.requiresApproval = requiresApproval
        self.feeOptions = feeOptions
        self.payloadFees = payloadFees
        self.batteryPayload = batteryPayload
        self.spentSourceAmount = spentSourceAmount
        self.sourceAmount = sourceAmount
        self.nativeFeeShortage = nativeFeeShortage
    }
}
