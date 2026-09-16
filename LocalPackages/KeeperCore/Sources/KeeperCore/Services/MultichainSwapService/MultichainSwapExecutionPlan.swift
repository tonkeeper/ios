public struct MultichainSwapExecutionPlan: Sendable {
    public var routeId: String
    /// The aggregator that issued the route: `providerRouteId` is only meaningful against it, and
    /// the signing pipeline is picked from it, so both stay in step by construction.
    public var aggregator: MultichainSwapAggregator
    public var providerRouteId: String?
    public var payloads: MultichainSwapRoutePayloads
    public var networkFees: [MultichainTransactionEmulationResult]
    public var requiresApproval: Bool
    /// Battery first, the source chain's own coin last; empty until the fee methods are resolved.
    public var feeOptions: [MultichainSwapFeeOption]
    var payloadFees: MultichainSwapPayloadFees
    /// The main payload in the shape a battery method sends it, so a chosen method needs no re-derivation.
    var batteryPayload: MultichainSwapBatteryPayload?

    public var provider: MultichainSwapProvider {
        aggregator.provider
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
        batteryPayload: MultichainSwapBatteryPayload? = nil
    ) {
        self.routeId = routeId
        self.aggregator = aggregator
        self.providerRouteId = providerRouteId
        self.payloads = payloads
        self.networkFees = networkFees
        self.requiresApproval = requiresApproval
        self.feeOptions = feeOptions
        self.payloadFees = payloadFees
        self.batteryPayload = batteryPayload
    }
}
